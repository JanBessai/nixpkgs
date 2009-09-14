{stdenv, fetchurl}:

let
  preBuildNoNative = ''
      # Make Cwd work on NixOS (where we don't have a /bin/pwd).
      substituteInPlace lib/Cwd.pm --replace "'/bin/pwd'" "'$(type -tP pwd)'"
    '';
  preBuildNative = "";
in
stdenv.mkDerivation {
  name = "perl-5.10.0";

  src = fetchurl {
    url = mirror://cpan/src/perl-5.10.0.tar.gz;
    sha256 = "0bivbz15x02m02gqs6hs77cgjr2msfrhnvp5xqk359jg6w6llill";
  };

  patches = [
    # This patch does the following:
    # 1) Do use the PATH environment variable to find the `pwd' command.
    #    By default, Perl will only look for it in /lib and /usr/lib.
    #    !!! what are the security implications of this?
    # 2) Force the use of <errno.h>, not /usr/include/errno.h, on Linux
    #    systems.  (This actually appears to be due to a bug in Perl.)
    ./no-sys-dirs.patch
  ];

  # Build a thread-safe Perl with a dynamic libperls.o.  We need the
  # "installstyle" option to ensure that modules are put under
  # $out/lib/perl5 - this is the general default, but because $out
  # contains the string "perl", Configure would select $out/lib.
  # Miniperl needs -lm. perl needs -lrt.
  configureFlags = [
    "-de"
    "-Dcc=gcc"
    "-Uinstallusrbinperl"
    "-Dinstallstyle=lib/perl5"
    "-Duseshrplib"
    (if stdenv ? glibc then "-Dusethreads" else "")
  ];

  configureScript = "${stdenv.shell} ./Configure";

  dontAddPrefix = true;

  configurePhase =
    ''
      configureFlags="$configureFlags -Dprefix=$out -Dman1dir=$out/share/man/man1 -Dman3dir=$out/share/man/man3"
      
      if test "$NIX_ENFORCE_PURITY" = "1"; then
        GLIBC=$(cat $NIX_GCC/nix-support/orig-libc)
        configureFlags="$configureFlags -Dlocincpth=$GLIBC/include -Dloclibpth=$GLIBC/lib"
      fi
      ${stdenv.shell} ./Configure $configureFlags \
      ${if stdenv.system == "armv5tel-linux" then "-Dldflags=\"-lm -lrt\"" else ""};
    '';

  preBuild = if (stdenv.gcc.nativeTools) then preBuildNative else preBuildNoNative;

  setupHook = ./setup-hook.sh;
}
