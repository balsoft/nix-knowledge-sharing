{ runCommand, mkDoc, texlive, pandoc, fontconfig, google-fonts, python3, which
, proselint, pandoc-lua-filters }:
let
  texlive-packages = {
    inherit (texlive)
      scheme-small noto mweights cm-super cmbright fontaxes beamer minted
      fvextra catchfile xstring framed;
  };

  texlive-combined = texlive.combine texlive-packages;

in mkDoc {
  name = "nix-knowledge-sharing";
  src = ./.;
  font = google-fonts;
  inherit texlive-combined;
  LUA_FILTERS = pandoc-lua-filters;
  HOME = "/build";
  extraBuildInputs = [ which python3.pkgs.pygments ];
  checkInputs = [ proselint ];
  checkPhase = "make check";
}
