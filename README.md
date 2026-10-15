# Dipole Fit for Alakazam

A plugin for [Alakazam](https://github.com/markspan/Alakazam): an equivalent current dipole, or a pair mirrored across the midline, fitted to a bin's scalp distribution over a time window by FieldTrip's `ft_dipolefitting`, with the share of the data it leaves unexplained.

It was part of Alakazam until it became a plugin of its own, so that it can be
installed, upgraded and documented on its own.

## Manual

The manual is on this repository's pages:
<https://markspan.github.io/AlakazamDipolefit/>.

## Installing

In Alakazam, **Install plugins** on the Alakazam tab lists this repository:
select it and press **Install**. It installs the latest release. A zip from
the [releases](https://github.com/markspan/AlakazamDipolefit/releases), or one built with
`build`, installs the same way through **From a link**, and so does the link
to this repository. The tool appears on the Tools tab, as it did before.

It needs Alakazam V0.4.5.3 or newer, the first without `DipoleFit` built
in. Workspaces and templates made with the built-in tool open and
recalculate as before once the plugin is installed; Alakazam offers to
install it when one needs it.

## Building and testing

```matlab
build()                                    % dist/DipoleFit-<version>.zip
runtests('tests')                          % the tool's tests and the install
```

The tests need Alakazam's source: the folder in `ALAKAZAM_ROOT`, or the
Alakazam repository beside this one.

The tests need FieldTrip, and skip without it; they never download it. FieldTripTutorialDipoleTest also needs the data of FieldTrip's dipole fitting tutorial, under FieldTrip/natmeg2014/dipolefitting in the data folder (ALAKAZAM_DATA, Alakazam's Data folder, or D:\data).

## Licence

GPL-3.0, as Alakazam.
