FROM ubuntu:20.04
LABEL org.opencontainers.image.authors="Matthew Zipay <a85:D0fo8@<k+RASuTBARoo>"

# override this if you have more than 2 cores available!
# (but note that OpenFOAM caps it at 8)
ARG NUMPROCS=2

SHELL ["/bin/bash", "-c"]

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get install -y g++-7 gcc-7 && \
	update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 && \
	update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 && \
	update-alternatives --set gcc /usr/bin/gcc-7 && \
	update-alternatives --set g++ /usr/bin/g++-7 && \
	useradd -m -s /bin/bash hy2user && \
	export HOME=/home/hy2user && \
	wget -O /tmp/OpenFOAM-v1706.tgz https://sourceforge.net/projects/openfoam/files/v1706/OpenFOAM-v1706.tgz && \
	wget -O /tmp/ThirdParty-v1706.tgz https://sourceforge.net/projects/openfoam/files/v1706/ThirdParty-v1706.tgz && \
	mkdir -p /opt/OpenFOAM && \
	cd /opt/OpenFOAM && \
	tar -zxf /tmp/OpenFOAM-v1706.tgz && \
	tar -zxf /tmp/ThirdParty-v1706.tgz && \
	rm -rf /tmp/OpenFOAM-v1706.tgz /tmp/ThirdParty-v1706.tgz && \
	apt-get install -y build-essential flex bison cmake zlib1g-dev libboost-system-dev libboost-thread-dev libopenmpi-dev openmpi-bin gnuplot libreadline-dev libncurses-dev libxt-dev && \
	apt-get install -y software-properties-common && \
	add-apt-repository -y ppa:rock-core/qt4 && \
	apt-get update && \
	apt-get install -y qt4-dev-tools libqt4-dev libqt4-opengl-dev freeglut3-dev libqtwebkit-dev && \
	apt-get install -y libscotch-dev libcgal-dev && \
	echo '. /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc' >> /home/hy2user/.bashrc && \
	. /opt/OpenFOAM/OpenFOAM-v1706/etc/bashrc && \
	export WM_NCOMPPROCS=$NUMPROCS && \
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
	cd hyStrath/ && \
	./install.sh $NUMPROCS && \
	rm -rf .git && \
	find $WM_PROJECT_USER_DIR/hyStrath -name "*.o" -delete 2>/dev/null || true && \
	find $WM_PROJECT_USER_DIR/hyStrath -name "*.dep" -delete 2>/dev/null || true && \
	chown -R hy2user:hy2user /home/hy2user && \
	su hy2user -c '. /home/hy2user/.bashrc && test -x "$FOAM_APPBIN/hy2Foam"' && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

USER hy2user

ENTRYPOINT ["/bin/bash", "-l"]

