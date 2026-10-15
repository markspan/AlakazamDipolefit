classdef DipoleFitTest < matlab.unittest.TestCase
%DIPOLEFITTEST  Dipole Fit finds a dipole that was put there.
%
%   A dipole (or a mirrored pair) is placed in FieldTrip's template head,
%   its scalp field computed by FieldTrip's own forward model, a little
%   noise added, and the result fitted: the fitted position must lie within
%   a centimetre of the true one, with a low residual variance. The same
%   head model simulates and fits, so this checks the pipeline (channel
%   order, units, the window, the model, the reference), not anatomical
%   accuracy, which no template can promise. Needs FieldTrip, skips without.
%
%   The view of the fit, DipoleView, is Alakazam's and tested there
%   (DipoleViewTest).
%
%   See also DIPOLEFIT, DIPOLEVIEW.

    properties (Constant)
        Labels = {'Fp1', 'Fp2', 'AF3', 'AF4', 'F7', 'F3', 'Fz', 'F4', 'F8', 'FC5', 'FC1', ...
                  'FC2', 'FC6', 'T7', 'C3', 'Cz', 'C4', 'T8', 'CP5', 'CP1', 'CP2', 'CP6', ...
                  'P7', 'P3', 'Pz', 'P4', 'P8', 'PO3', 'PO4', 'O1', 'Oz', 'O2'}
    end

    methods (TestClassSetup)
        function addSourceToPath(testCase)
            plugin = fileparts(fileparts(mfilename('fullpath')));
            root = getenv('ALAKAZAM_ROOT');   % Alakazam's source, which the plugin runs in
            if isempty(root)
                root = fullfile(fileparts(plugin), 'Alakazam');
            end
            testCase.assumeTrue(isfolder(fullfile(root, 'src')), ...
                'Alakazam''s source is not found (set ALAKAZAM_ROOT).');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(plugin, 'tests')));
            for p = {fullfile(root, 'src'), fullfile(root, 'src', 'Support'), ...
                     fullfile(root, 'src', 'Views'), fullfile(root, 'src', 'Transformations'), ...
                     fullfile(plugin, 'DipoleFit')}
                testCase.applyFixture(matlab.unittest.fixtures.PathFixture(p{1}));
            end
        end

        function requireFieldTrip(testCase)
            FieldTripFixtures.require(testCase);
        end
    end

    methods (Test)
        function findsTheDipoleThatWasPutThere(testCase)
            truth = [-48 -22 4];
            avg = testCase.simulate(truth, [0.3 0.2 0.93]);
            % fminsearch, FieldTrip's documented option, so the fit runs on a
            % MATLAB where FieldTrip's own choice, fminunc, cannot (see
            % theFitIsLeftToFieldTripsOwnDefaults for the default).
            result = FieldTripFixtures.quietly(@() DipoleFit(avg, struct('Bins', {{'A'}}, ...
                'WindowStart', 80, 'WindowStop', 120, 'Model', 'One dipole', 'GridResolution', 10, ...
                'Optimiser', 'fminsearch')));
            fit = result.dipoleFit;
            testCase.verifyEqual(fit.bin, 'A');
            testCase.verifySize(fit.pos, [1 3]);
            testCase.verifyLessThan(norm(fit.pos - truth), 10, ...
                sprintf('Fitted at [%s], put at [%s].', num2str(fit.pos, '%.0f '), num2str(truth)));
            testCase.verifyTrue(isscalar(fit.rv), 'One residual variance for the window.');
            testCase.verifyLessThan(fit.rv, 0.05);
            testCase.verifyEqual(fit.gof, 1 - fit.rv, 'AbsTol', 1e-12);
            testCase.verifyNumElements(fit.rvTime, numel(fit.time), 'FieldTrip''s own, per sample.');
            testCase.verifyEqual(fit.time([1 end]), [80 120], 'AbsTol', 1e-9, 'The window, in ms.');
            testCase.verifyTrue(contains(fit.region{1}, '_L'), ...
                sprintf('A left-hemisphere position is named as one (%s).', fit.region{1}));
            testCase.verifyEqual(result.data, avg.data, 'The data are not changed.');
        end

        function theFitIsLeftToFieldTripsOwnDefaults(testCase)
        %THEFITISLEFTTOFIELDTRIPSOWNDEFAULTS  The optimiser and the inside
        %   check are FieldTrip's to choose, as in a script: fminunc where it
        %   finds the Optimization Toolbox and fminsearch otherwise, and
        %   checkinside false. They used to be fixed at fminsearch and true.
            testCase.standInForFieldTrip(true);
            avg = testCase.simulate([-48 -22 4], [0.3 0.2 0.93]);

            FieldTripFixtures.quietly(@() DipoleFit(avg, struct('Bins', {{'A'}}, ...
                'WindowStart', 80, 'WindowStop', 120, 'Model', 'One dipole', 'GridResolution', 10)));

            dipfit = DipoleFitTest.dipfitHandedOver(testCase);
            testCase.verifyFalse(isfield(dipfit, 'optimfun'), 'The optimiser is FieldTrip''s choice.');
            testCase.verifyFalse(isfield(dipfit, 'checkinside'), 'So is the inside check.');
        end

        function fminsearchIsFieldTripsOwnOptionWhenChosen(testCase)
        %FMINSEARCHISFIELDTRIPSOWNOPTIONWHENCHOSEN  For a MATLAB where
        %   FieldTrip's choice cannot run, the Optimiser sets its documented
        %   cfg.dipfit.optimfun.
            testCase.standInForFieldTrip(true);
            avg = testCase.simulate([-48 -22 4], [0.3 0.2 0.93]);

            FieldTripFixtures.quietly(@() DipoleFit(avg, struct('Bins', {{'A'}}, ...
                'WindowStart', 80, 'WindowStop', 120, 'Model', 'One dipole', 'GridResolution', 10, ...
                'Optimiser', 'fminsearch')));

            dipfit = DipoleFitTest.dipfitHandedOver(testCase);
            testCase.verifyEqual(dipfit.optimfun, 'fminsearch');
            testCase.verifyFalse(isfield(dipfit, 'checkinside'));
        end

        function aFitThatStopsSaysWhichSettingToChange(testCase)
        %AFITTHATSTOPSSAYSWHICHSETTINGTOCHANGE  FieldTrip hands back the grid
        %   search's starting point, with no residual variance, when its
        %   optimiser stops with an error; the refusal names the Optimiser.
            testCase.standInForFieldTrip(false);
            avg = testCase.simulate([-48 -22 4], [0.3 0.2 0.93]);

            try
                FieldTripFixtures.quietly(@() DipoleFit(avg, struct('Bins', {{'A'}}, ...
                    'WindowStart', 80, 'WindowStop', 120, 'Model', 'One dipole', 'GridResolution', 10)));
                err = MException('none:none', 'no error');
            catch err
            end

            testCase.verifyEqual(err.identifier, 'Alakazam:DipoleFit');
            testCase.verifySubstring(err.message, 'set the Optimiser to fminsearch');
        end

        function findsAMirroredPair(testCase)
            truth = [-46 -24 6; 46 -24 6];
            avg = testCase.simulate(truth, [0.2 0.1 0.97; -0.2 0.1 0.97]);
            result = FieldTripFixtures.quietly(@() DipoleFit(avg, struct('Bins', {{'A'}}, ...
                'WindowStart', 80, 'WindowStop', 120, 'Model', 'Mirrored pair', 'GridResolution', 10, ...
                'Optimiser', 'fminsearch')));
            fit = result.dipoleFit;
            testCase.verifySize(fit.pos, [2 3]);
            testCase.verifyEqual(fit.pos(1, 2:3), fit.pos(2, 2:3), 'AbsTol', 1e-6, 'Mirrored across x.');
            testCase.verifyEqual(fit.pos(1, 1), -fit.pos(2, 1), 'AbsTol', 1e-6);
            left = fit.pos(fit.pos(:, 1) < 0, :);
            testCase.verifyLessThan(norm(left - truth(1, :)), 10);
            testCase.verifyLessThan(fit.rv, 0.05);
        end

        function aWindowThatEndsBeforeItStartsIsRefused(testCase)
            avg = testCase.simulate([-48 -22 4], [0 0 1]);
            testCase.verifyError(@() DipoleFit(avg, struct('Bins', {{'A'}}, 'WindowStart', 120, ...
                'WindowStop', 80)), 'Alakazam:DipoleFit');
        end
    end

    methods (Static, Access = private)
        function dipfit = dipfitHandedOver(testCase)
        %DIPFITHANDEDOVER  The cfg.dipfit the stand-in was given.
            cfg = getappdata(groot, 'DipoleFitTestCfg');
            testCase.assertNotEmpty(cfg, 'The stand-in was not the one called.');
            dipfit = struct();
            if isfield(cfg, 'dipfit')
                dipfit = cfg.dipfit;
            end
        end
    end

    methods (Access = private)
        function standInForFieldTrip(testCase, withRv)
        %STANDINFORFIELDTRIP  A stand-in ft_dipolefitting first on the path
        %   for this test: it records the cfg it is handed and returns a fit,
        %   with a residual variance or (WITHRV false) without one, as
        %   FieldTrip returns when its optimiser stops.
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            dip = '''pos'', [-48 -22 4], ''mom'', [1; 0; 0]';
            if withRv
                dip = [dip ', ''rv'', 0.1'];
            end
            fid = fopen(fullfile(folder, 'ft_dipolefitting.m'), 'w');
            fprintf(fid, '%s\n', ...
                'function source = ft_dipolefitting(cfg, data)', ...
                'setappdata(groot, ''DipoleFitTestCfg'', cfg);', ...
                ['source = struct(''dip'', struct(' dip '), ...'], ...
                '    ''Vdata'', data.avg, ''Vmodel'', 0.9 * data.avg, ''time'', data.time);', ...
                'end');
            fclose(fid);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            setappdata(groot, 'DipoleFitTestCfg', []);
            testCase.addTeardown(@() rmappdata(groot, 'DipoleFitTestCfg'));
        end

        function avg = simulate(testCase, positions, moments)
        %SIMULATE  An averaged dataset holding the field of the dipoles, a
        %   Gaussian in time peaking at 100 ms, with noise at a fortieth of it.
            [~, ~, labels, elec, headmodel] = FieldTripFixtures.quietly(@() ...
                TransTools.BuildSourceForwardModel(testCase.Labels, 5124));
            [headmodel, elec] = FieldTripFixtures.quietly(@() ft_prepare_vol_sens(headmodel, elec));
            topography = zeros(numel(labels), 1);
            for k = 1:size(positions, 1)
                lf = FieldTripFixtures.quietly(@() ft_compute_leadfield(positions(k, :), elec, headmodel));
                topography = topography + lf * (moments(k, :)' / norm(moments(k, :)));
            end
            times = -100:4:300;
            course = exp(-((times - 100) / 25) .^ 2);
            clean = topography * course;
            rng(3);
            noisy = clean + randn(size(clean)) * max(abs(clean(:))) / 40;

            avg = struct('data', noisy, 'times', times, 'srate', 250, 'pnts', numel(times), ...
                'nbchan', numel(labels), 'trials', 1, 'DataFormat', 'AVERAGED', ...
                'DataType', 'TimeDomain', 'File', 'simulated.set', 'id', 'Average');
            avg.chanlocs = struct('labels', cellstr(string(labels(:)))');
            avg.chanlocs = avg.chanlocs(:)';
            avg.bindesc = struct('index', 1, 'label', 'A', 'trials', [], 'combo', [], 'n', 50);
        end
    end
end
