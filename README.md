# 🐝 Flake Buzz

A Nix flake for [Buzz](https://github.com/chidiwilliams/buzz), a state-of-the-art offline audio transcription and translation tool powered by OpenAI's Whisper.

This flake packages Buzz using a Nix FHS (Filesystem Hierarchy Standard) environment, ensuring seamless audio driver integration (ALSA/PulseAudio/PortAudio), Qt6 UI rendering, and full **NVIDIA CUDA GPU acceleration** support.

---

## 🚀 Quick Start

Run Buzz directly without installing it:

```bash
nix run github:hmahonen/flake-buzz
```

Or clone the repository and run it locally:

```bash
nix run
```

---

## 🛠️ NixOS Integration

To integrate this flake into your NixOS configuration:

### 1. Add to your Flake Inputs

```nix
inputs = {
  flake-buzz.url = "github:hmahonen/flake-buzz";
};
```

### 2. Add to your System Packages or Dev Shell

```nix
environment.systemPackages = [
  inputs.flake-buzz.packages.${system}.default
];
```
