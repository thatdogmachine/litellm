{
  description = "Development environment for litellm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [ "aarch64-darwin" ];
      forAllSystems = lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          stdenv = pkgs.stdenv;
          pythonPackages = pkgs.python3Packages;

          # Define local scripts here (llxpert scripts)
          llxpert-script = pkgs.writeShellScriptBin "llxpert-logging" ''
            #!/bin/sh
            node /Users/$(whoami)/repos/llxprt-code/packages/cli \
              --include-directories ~/repos/llxprt-code \
              "$@"
          '';
          llxpert-logging-script = pkgs.writeShellScriptBin "llxpert-local" ''
            #!/bin/sh
            node /Users/$(whoami)/repos/logging-cli \
              --include-directories ~/repos/llxprt-code \
              "$@"
          '';
          
          # Define venv directory location
          venvDir = "./.venv";

        in
        {
          default = pkgs.mkShell {
            
            # Packages needed in the shell environment
            packages = with pkgs;[
              nodejs
              poetry # Poetry is required to run the install script
              llxpert-logging-script
              llxpert-script
              zsh
            ];

            # buildInputs: Packages that provide libraries or shell hooks
            buildInputs = [
              pythonPackages.python
            ];
            
            # (Optional: kept for clear documentation of intent)
            venvDir = venvDir;

            # consolidated shell hook that manages venv creation and environment setup
            shellHook = ''
              unset SOURCE_DATE_EPOCH
              
              # --- 1. Poetry Environment Configuration ---
              # This variable forces Poetry to create the virtual environment 
              # inside the project directory (.venv) instead of the global cache.
              export POETRY_VIRTUALENVS_IN_PROJECT=true
              
              # --- 2. Venv Setup (Runs only on first entry) ---
              # We check for the venv directory created by poetry
              if [ ! -d "$venvDir" ]; then
                echo "--- Setting up Python Virtual Environment and installing dependencies ---"
                
                # Poetry automatically finds and uses the python provided by Nix
                ${pkgs.poetry}/bin/poetry install
                
                echo "--- Python environment setup complete. ---"
              fi
              
              # --- 3. Activate the virtual environment ---
              # We need to activate the environment created by poetry
              source ${venvDir}/bin/activate
              
              # --- 4. Final Environment Setup ---
              # Fixes library linking (LD_LIBRARY_PATH)
              export LD_LIBRARY_PATH=${lib.makeLibraryPath [stdenv.cc.cc]}
              
              # Print diagnostics and welcome messages
              poetry env info
              echo "The 'llxpert-local' command is now available."
              echo "The 'llxpert-logging' command is now available."

              # --- 5. Zsh Shell Switch (LAST STEP) ---
              # Checks if we are currently running Zsh. If not, switch to it.
              if [ -z "$IN_NIX_SHELL_ZSH" ]; then
                export IN_NIX_SHELL_ZSH=1
                export SHELL=${pkgs.zsh}/bin/zsh
                echo "Switching to zsh..."
                
                # exec replaces the current bash process with the new zsh process
                exec $SHELL
              fi
            '';
            
            # Removed redundant postShellHook and postVenvCreation
          };
        });
    };
}