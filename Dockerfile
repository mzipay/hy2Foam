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

FROM ubuntu:20.04
LABEL org.opencontainers.image.authors="Matthew Zipay <a85:D0fo8@<k+RASuTBARoo>"

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

ARG WANTED_PACKAGES="\
 nano-tiny \
"

# override this if you have more than 2 cores available!
# (but note that OpenFOAM caps it at 8)
ARG NPROCS=2

# Git branch or tag to check out
ARG HYSTRATH_BRANCH="Williamina-Fleming"

# NOTE: this Docker-specific, so need to use "--format docker" for podman!
SHELL ["/bin/bash", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install -y --no-install-recommends ${BUILD_PACKAGES} ${REQUIRED_PACKAGES} ${WANTED_PACKAGES} && \
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
	echo "CORE_OPENFOAM_BUILD_VERIFIED" && \
	find build -name "*.o" -delete 2>/dev/null || true && \
	find build -name "*.dep" -delete 2>/dev/null || true && \
	rm -rf build && \
	mkdir -p "${WM_PROJECT_USER_DIR}" && \
	chown -R hy2user:hy2user /home/hy2user && \
	apt-get purge --auto-remove -y ${BUILD_PACKAGES}

USER hy2user

ENTRYPOINT ["/bin/bash", "-l"]

