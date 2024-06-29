{ lib, nixosOptionsDoc, nuscht-search, python3, runCommand, xorg }:

rec {
  mkOptionsJSON = modules:
    let
      patchedModules = [ { config._module.check = false; } ] ++ modules;
      inherit (lib.evalModules { modules = patchedModules; }) options;
    in
    (nixosOptionsDoc {
      options = lib.filterAttrs (key: _: key != "_module") options;
      warningsAreErrors = false;
    }).optionsJSON + /share/doc/nixos/options.json;

  mkSearchJSON = searchArgs:
    runCommand "options.json"
      { nativeBuildInputs = [ (python3.withPackages (ps: with ps; [ markdown pygments ])) ]; }
      (''
        mkdir $out
        python \
          ${./fixup-options.py} \
      '' + lib.concatStringsSep " " (lib.flatten (map (opt: [
        (opt.optionsJSON or mkOptionsJSON opt.modules) "'${opt.urlPrefix}'"
        ]) searchArgs)) + ''
          > $out/options.json
      '');

  mkSearch = { modules ? null, optionsJSON ? null, urlPrefix }:
    let
      args = {
        inherit urlPrefix;
      } // lib.optionalAttrs (modules != null) modules
        // lib.optionalAttrs (optionsJSON != null) optionsJSON;
    in
    runCommand "nuscht-search"
      { nativeBuildInputs = [ xorg.lndir ]; }
      ''
        mkdir $out
        lndir ${nuscht-search} $out
        ln -s ${mkSearchJSON [ args ]} $out/options.json
      '';

  # mkMultiSearch [
  #   { modules = [ self.inputs.nixos-modules.nixosModule ]; urlPrefix = "https://github.com/NuschtOS/nixos-modules/blob/main/"; }
  #   { optionsJSON = ./path/to/options.json; urlPrefix = "https://git.example.com/blob/main/"; }
  # ]
  mkMultiSearch = searchArgs:
    runCommand "nuscht-search"
      { nativeBuildInputs = [ xorg.lndir ]; }
      ''
        mkdir $out
        lndir ${nuscht-search} $out
        ln -s ${mkSearchJSON searchArgs}/options.json $out/options.json
      '';
}
