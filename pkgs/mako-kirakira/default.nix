{lib, mako}:
assert lib.assertMsg (mako.version == "1.11.0") "Review Blackmoon's Mako rendering patch when upgrading Mako.";
mako.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./kirakira.patch];
})
