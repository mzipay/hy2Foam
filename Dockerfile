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
 git \
 wget \
"

ARG REQUIRED_PACKAGES="\
 bc \
 bison \
 build-essential \
 cmake \
 flex \
 gnuplot \
 libboost-system-dev \
 libboost-thread-dev \
 libncurses-dev \
 libopenmpi-dev \
 libreadline-dev \
 libxt-dev \
 openmpi-bin \
 software-properties-common \
 zlib1g-dev \
"

ARG OPTIONAL_PACKAGES_QT4="\
 qt4-dev-tools \
 libqt4-dev \
 libqt4-opengl-dev \
 freeglut3-dev \
 libqtwebkit-dev \
 libscotch-dev \
 libcgal-dev \
"

ARG WANTED_PACKAGES="\
 nano-tiny \
 neovim \
"

# override this if you have more than 2 cores available!
# (but note that OpenFOAM caps it at 8)
ARG NPROCS=2

# NOTE: this Docker-specific, so need to use "--format docker" for podman!
SHELL ["/bin/bash", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install -y g++-7 gcc-7 && \
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 && \
	update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 && \
	update-alternatives --set gcc /usr/bin/gcc-7 && \
	update-alternatives --set g++ /usr/bin/g++-7 && \
	apt-get install -y ${BUILD_PACKAGES} ${REQUIRED_PACKAGES} ${WANTED_PACKAGES} && \
	add-apt-repository -y ppa:rock-core/qt4 && \
	apt-get update && \
	apt-get install -y ${OPTIONAL_PACKAGES_QT4} && \
	useradd -m -s /bin/bash hy2user && \
	export HOME=/home/hy2user && \
	wget -O /tmp/OpenFOAM-v1706.tgz https://sourceforge.net/projects/openfoam/files/v1706/OpenFOAM-v1706.tgz && \
	wget -O /tmp/ThirdParty-v1706.tgz https://sourceforge.net/projects/openfoam/files/v1706/ThirdParty-v1706.tgz && \
	mkdir -p /opt/OpenFOAM && \
	cd /opt/OpenFOAM && \
	tar -zxf /tmp/OpenFOAM-v1706.tgz && \
	tar -zxf /tmp/ThirdParty-v1706.tgz && \
	rm -rf /tmp/OpenFOAM-v1706.tgz /tmp/ThirdParty-v1706.tgz && \
	echo '. /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc' >> /home/hy2user/.bashrc && \
	. /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc && \
	export WM_NCOMPPROCS=${NPROCS} && \
	cd $WM_THIRD_PARTY_DIR && \
	./Allwmake && \
	rm -rf build gcc-* gmp-* mpfr-* binutils-* boost* ParaView-* qt-* *.tgz *.tar.gz && \
	cd $WM_PROJECT_DIR && \
	./Allwmake && \
	find build -name "*.o" -delete 2>/dev/null || true && \
	find build -name "*.dep" -delete 2>/dev/null || true && \
	rm -rf build && \
	mkdir -p "$WM_PROJECT_USER_DIR" && \
	cd $WM_PROJECT_USER_DIR && \
	git clone --depth 1 --branch master --single-branch https://github.com/hystrath/hyStrath.git && \
	cd hyStrath && \
	sed -i '/^progress_bar()/,/^}/c\progress_bar() { :; }' install.sh && \
	echo "1" | ./install.sh ${NPROCS} && \
	su hy2user -c '. /home/hy2user/.bashrc && test -x "$FOAM_APPBIN/hy2Foam"' && \
	rm -rf .git && \
	find $WM_PROJECT_USER_DIR/hyStrath -name "*.o" -delete 2>/dev/null || true && \
	find $WM_PROJECT_USER_DIR/hyStrath -name "*.dep" -delete 2>/dev/null || true && \
	chown -R hy2user:hy2user /home/hy2user && \
	apt-get purge --auto-remove -y ${BUILD_PACKGES} && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

USER hy2user

ENTRYPOINT ["/bin/bash", "-l"]

