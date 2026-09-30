# ninthtest/hy2foam

> hy2Foam-container: a Dockerfile for building the hy2Foam CFD solver in OCI
> Copyright (C) 2026  Matthew Zipay
>
> This program is free software: you can redistribute it and/or modify
> it under the terms of the GNU Affero General Public License as published by
> the Free Software Foundation, either version 3 of the License, or
> (at your option) any later version.
>
> This program is distributed in the hope that it will be useful,
> but WITHOUT ANY WARRANTY; without even the implied warranty of
> MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
> GNU Affero General Public License for more details.
>
> You should have received a copy of the GNU Affero General Public License
> along with this program.  If not, see <https://www.gnu.org/licenses/>.

This project contains the multi-stage *Dockerfile* used to create an OCI image
for the [hy2Foam](https://hystrath.github.io/solvers/fleming/hy2foam/) flow
solver.

## Apptainer instructions

To create an [Apptainer](https://apptainer.org/) SIF file from the latest image:

```console
apptainer build hy2foam.sif docker://ghcr.io/mzipay/hy2foam
```

## Docker instructions

> [!TIP]
> NPROCS=2 here is just a "safe" default.
>
> The "ideal" value to use for the NPROCS build argument depends on your host
> system. For the quickest build, use *min(your-CPU-cores, 8)*.

```console
docker build --build-arg NPROCS=2 -t hy2foam .
```

### By stage

> [!TIP]
> These steps are only useful for local testing of changes to individual
> stages in *Dockerfile*.
>
> For most users, the `docker build` instruction above is sufficient to produce
> the final image.

Stage 1 (openfoam):

```console
docker build --build-arg NPROCS=2 --target openfoam -t of1706 .
```

Stage 2 (hystrath):

```console
docker build --build-arg NPROCS=2 --target hystrath -t hydev .
```

Stage 3 (runtime):

```console
docker build --build-arg NPROCS=2 -t hy2foam .
```

## Podman instructions

Simply change the above-mentioned `docker` commands into
`podman --format docker` commands. (All other arguments remain the same.)
