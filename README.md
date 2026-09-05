<p align="center">
    <img alt="Pixel art of a small creature floating inside a black bubble" width="160" src="logo/logo.png">
</p>

`agent-sandbox` provides a [Nix][] package for running agents in an opinionated [Bubblewrap][] sandbox.

> [!NOTE]
> Currently, only [Pi][] is wired up. Contributions to include more agents are welcome!

## Usage

You can run it directly with the default configuration to use the current
directory as the working directory.[^workdir]

[^workdir]: Some directories, such as `$HOME`, are considered too sensitive, and `agent` will refuse to run.

```shell
nix run github:interrato/agent-sandbox
```

Alternatively, you can add it to your NixOS configuration.

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    agent-sandbox = {
      url = "github:interrato/agent-sandbox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, agent-sandbox, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          environment.systemPackages = [
            agent-sandbox.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Configuration

You can use `override` to customize the `agent` package. The following options are currently available.

#### `agentName` (default: `"pi"`)

The name of the agent that will run.

#### `env` (default: `{ }`)

Environment variables to set for the sandboxed environment.

#### `packages` (default: `[ ]`)

Extra packages to include in the sandboxed environment.

#### `TERM` (default: `"xterm-256color"`)

The name of the [terminfo][] entry used to determine the capabilities of the terminal.

#### `TERMINFO` (default: `"${ncurses}/share/terminfo"`)

A path containing the selected terminfo entry.

Here is an example for [Ghostty][].

```nix
agent-sandbox.packages.x86_64-linux.default.override {
  packages = [ pkgs.ghostty.terminfo ];
  TERM = "xterm-ghostty";
  TERMINFO = "${pkgs.ghostty.terminfo}/share/terminfo";
}
```

#### `networkSupport` (default: `true`)

Whether to enable network sharing and include networking tools.

#### `pdfSupport` (default: `true`)

Whether to include tools for reading, editing, and creating PDFs.

#### `docSupport` (default: `false`)

Whether to include tools for manipulating various document formats, such as
spreadsheets, presentations, and word processing documents.

#### `cryptoSupport` (default: `false`)

Whether to include tools for performing cryptographic operations.

#### `proverSupport` (default: `false`)

Whether to include proof assistants and formal verification tools.

#### `nodeSupport` (default: `agentName == "pi"`)

Whether to include [Node.js][].

#### `pythonSupport` (default: `true`)

Whether to include a [Python][] environment with some packages, depending on
the options above.

[Nix]: https://nixos.org
[Bubblewrap]: https://github.com/containers/bubblewrap
[Pi]: https://pi.dev
[terminfo]: https://en.wikipedia.org/wiki/Terminfo
[Ghostty]: https://ghostty.org
[Node.js]: https://nodejs.org
[Python]: https://www.python.org
