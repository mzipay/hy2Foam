# hy2Foam: Dockerfile for building the hy2Foam CFD solver as an OCI image
# Copyright (C) 2026 Matthew Zipay
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Targets:
#   --target openfoam	verified OpenFOAM-v1706 only
#   --target hystrath	OpenFOAM-v1706 + hyStrath, pruned & stripped
#   (default)			OpenFOAM-v1706 + hyStrath runtime image

###############################################################################
# Stage 1: OpenFOAM-v1706
###############################################################################
FROM ubuntu:20.04 AS openfoam
LABEL org.opencontainers.image.authors="Matthew Zipay"

ARG BUILD_PACKAGES="\
 bc \
 ca-certificates \
 git \
 wget \
"

ARG REQUIRED_PACKAGES="\
 bison \
 build-essential \
 cmake \
 flex \
 g++-7 \
 gcc-7 \
 gnuplot-nox \
 libboost-system-dev \
 libboost-thread-dev \
 libcgal-dev \
 libfl-dev \
 libncurses-dev \
 libopenmpi-dev \
 libreadline-dev \
 libscotch-dev \
 libxt-dev \
 openmpi-bin \
 zlib1g-dev \
"

# override this if you have more than 2 cores available!
# (but note that OpenFOAM caps it at 8)
ARG NPROCS=2

# NOTE: this is Docker-specific, so need to use "--format docker" for podman!
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install -y --no-install-recommends ${BUILD_PACKAGES} ${REQUIRED_PACKAGES} && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	update-ca-certificates && \
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 && \
	update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 && \
	update-alternatives --set gcc /usr/bin/gcc-7 && \
	update-alternatives --set g++ /usr/bin/g++-7 && \
	useradd -m -s /bin/bash hy2user && \
	export HOME=/home/hy2user && \
	wget -O /tmp/OpenFOAM-v1706.tgz https://sourceforge.net/projects/openfoam/files/v1706/OpenFOAM-v1706.tgz && \
	test -s /tmp/OpenFOAM-v1706.tgz && \
	wget -O /tmp/ThirdParty-v1706.tgz https://sourceforge.net/projects/openfoam/files/v1706/ThirdParty-v1706.tgz && \
	test -s /tmp/ThirdParty-v1706.tgz && \
	mkdir -p /opt/OpenFOAM && \
	cd /opt/OpenFOAM && \
	tar -zxf /tmp/OpenFOAM-v1706.tgz && \
	tar -zxf /tmp/ThirdParty-v1706.tgz && \
	rm -f /tmp/OpenFOAM-v1706.tgz /tmp/ThirdParty-v1706.tgz && \
	echo -e "\n. /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc" >> /home/hy2user/.bashrc && \
	. /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc && \
	export WM_NCOMPPROCS=${NPROCS} && \
	cd "${WM_THIRD_PARTY_DIR}" && \
	./Allwmake 2>&1 | tee /tmp/ThirdParty-v1706_Allwmake.log && \
	rm -rf build gcc-* gmp-* mpfr-* binutils-* boost* ParaView-* qt-* *.tgz *.tar.gz && \
	cd "${WM_PROJECT_DIR}" && \
	./Allwmake 2>&1 | tee /tmp/OpenFOAM-v1706_Allwmake.log && \
	test -d "$FOAM_APPBIN" && \
	test -x "$FOAM_APPBIN/blockMesh" && \
	test -x "$FOAM_APPBIN/checkMesh" && \
	test -x "$FOAM_APPBIN/icoFoam" && \
	test -x "$FOAM_APPBIN/simpleFoam" && \
	echo "======= OpenFOAM-v1706 (verified) =======" && \
	rm -rf build && \
	chown -R hy2user:hy2user /home/hy2user

USER hy2user

ENTRYPOINT ["/bin/bash", "-l"]

###############################################################################
# Stage 2: hyStrath, then prune build artifacts & strip binaries
###############################################################################
FROM openfoam AS hystrath
LABEL org.opencontainers.image.authors="Matthew Zipay"

# Git branch or tag to check out
ARG HYSTRATH_BRANCH="Williamina-Fleming"

ARG NPROCS=2

# 1 - CFD module
# 2 - DSMC module
# 3 - Hybrid PIC-DSMC module
# 4 - CFD-MHD module
# 5 - All modules
# TODO: This is not fully supported yet! Only option 1 is currently supported!
ARG HYSTRATH_INSTALLATION=1

USER root

# Make OpenFOAM resolve $WM_PROJECT_USER_DIR for hy2user, not root.
ENV USER=hy2user
ENV HOME=/home/hy2user

RUN . /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc && \
	export WM_NCOMPPROCS=${NPROCS} && \
	mkdir -p "${WM_PROJECT_USER_DIR}" && \
	cd "${WM_PROJECT_USER_DIR}" && \
	git clone --depth 1 --branch "${HYSTRATH_BRANCH}" --single-branch https://github.com/hystrath/hyStrath.git && \
	cd hyStrath && \
	sed -i '/^progress_bar()/,/^}/c\progress_bar() { :; }' install.sh && \
	sed -i 's/^\([[:space:]]*\)echo -e "Enter choice: \\c"[[:space:]]*$/\1echo "Building hyStrath..."/' install.sh && \
	echo "${HYSTRATH_INSTALLATION}" | ./install.sh ${NPROCS} 2>&1 | tee /tmp/hyStrath_install.log && \
	( test -x "${FOAM_USER_APPBIN}/hy2Foam" || test -x "${FOAM_APPBIN}/hy2Foam" ) && \
	echo "======= hyStrath (\"${HYSTRATH_BRANCH}\") (verified) ======="

# Prune build-only content and strip debug symbols.
# (Relax the ThirdParty line first if the runtime stage's ldd check fails.)
RUN . /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc && \
	rm -rf "${WM_PROJECT_USER_DIR}/hyStrath/.git" && \
	find "${WM_PROJECT_USER_DIR}/hyStrath" \( -name '*.o' -o -name '*.dep' \) -delete && \
	cd "${WM_PROJECT_USER_DIR}" && \
	find run/hyStrath -mindepth 1 -maxdepth 1 ! -name hy2Foam -exec rm -rf {} + && \
	rm -rf hyStrath/run/hyStrath hyStrath/doc && \
	ln -s ../../run/hyStrath hyStrath/run/hyStrath && \
	test -d run/hyStrath/hy2Foam && \
	test -L hyStrath/run/hyStrath && \
	ls hyStrath/run/hyStrath/hy2Foam > /dev/null && \
	rm -rf src applications hyStrath/src && \
	rm -rf "${WM_PROJECT_DIR}/src" "${WM_PROJECT_DIR}/applications" && \
	find "${WM_THIRD_PARTY_DIR}" -mindepth 1 -maxdepth 1 -type d \
		! -name platforms ! -name etc -exec rm -rf {} + && \
	find "${FOAM_APPBIN}" "${FOAM_LIBBIN}" "${FOAM_USER_APPBIN}" "${FOAM_USER_LIBBIN}" \
		-type f -exec strip --strip-unneeded {} \; 2>/dev/null ; \
	chown -R hy2user:hy2user /home/hy2user

###########################################################################
# Stage 3: runtime (default)
###########################################################################
FROM ubuntu:20.04 AS runtime
LABEL org.opencontainers.image.authors="Matthew Zipay"

ARG RUNTIME_PACKAGES="\
 bc \
 gnuplot-nox \
 libboost-system1.71.0 \
 libboost-thread1.71.0 \
 libgmp10 \
 libmpfr6 \
 libncurses6 \
 libopenmpi3 \
 libreadline8 \
 libscotch-6.0 \
 libxt6 \
 nano-tiny \
 openmpi-bin \
 zlib1g \
"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install -y --no-install-recommends ${RUNTIME_PACKAGES} && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	useradd -m -s /bin/bash hy2user

COPY --from=hystrath /opt/OpenFOAM /opt/OpenFOAM
COPY --from=hystrath --chown=hy2user:hy2user /home/hy2user /home/hy2user

ENV USER=hy2user
ENV HOME=/home/hy2user

# Fail the build if any shared library is missing, or a key binary is not on PATH.
RUN . /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc && \
	missing=$(find "${FOAM_APPBIN}" "${FOAM_LIBBIN}" "${FOAM_USER_APPBIN}" "${FOAM_USER_LIBBIN}" -type f 2>/dev/null \
		| xargs ldd 2>/dev/null | grep "not found" | sort -u || true) && \
	if [ -n "$missing" ]; then echo "MISSING LIBRARIES:"; echo "$missing"; exit 1; fi && \
	command -v blockMesh && command -v icoFoam && command -v hy2Foam && \
	echo "======= runtime (verified) ======="

USER hy2user

WORKDIR /home/hy2user

ENTRYPOINT ["/bin/bash", "-l"]

