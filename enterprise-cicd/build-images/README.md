# Platform Build Images

Platform-owned, versioned build environments used by governed CI profiles.

The source of truth is `versions.json`. V1 contains Java/Maven, Python/uv, Go, and C++/CMake+Conan images. Tags are immutable and application pipelines consume platform image versions rather than defining ad-hoc toolchains.

Publishing is an explicit protected operation through `.github/workflows/platform-build-images-publish.yml`:

1. validate `versions.json` and platform activation contracts;
2. authenticate to Azure with GitHub OIDC;
3. build the four images in a Matrix;
4. refuse to overwrite an existing `build/<image>:<version>` tag;
5. push the image to the selected ACR;
6. record the resolved registry digest as release evidence.

`confirm_publish=false` is the default. The workflow does not create Azure infrastructure and has no Kubernetes write path.
