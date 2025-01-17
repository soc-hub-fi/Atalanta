# Container reference for Rust toolchain

This directory contains Containerfiles that prove that the toolchain is installable on a particular
system. They can also be used as is for development.

| File                       | OS           |
| :-                         | :-           |
| Containerfile.Ubuntu.22.04 | Ubuntu 22.04 |

```sh
# Build a container
podman build -f Containerfile.Ubuntu.22.04

# Remove any builder stages to save space
podman image prune --filter label=stage=builder
```
