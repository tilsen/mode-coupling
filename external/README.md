# external/

Vendored from `st_tools`, so that this repository runs with nothing but
itself on the MATLAB path.

Two things to know before changing anything here:

- **It is deliberately broader than what this repository calls.** It also
  carries helpers used by figure code outside this repository. A
  dependency scan run from inside this repository will report a number of
  these files as having no caller. They are not dead.
- **Several files have since been developed past upstream.** `stFig.m`, for
  one, has gained features that `st_tools` does not have. Re-syncing from
  upstream would lose that work.
