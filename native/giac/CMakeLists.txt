cmake_minimum_required(VERSION 3.22)
project(fikajiana_giac C CXX)

# Mêmes fichiers que CMakeLists.txt de Giac, sans minigiac ni l'interface JNI.
set(G ${GIAC_SOURCES_DIR}/src/giac/cpp)
set(GIAC_FICHIERS
  alg_ext.cc cocoa.cc csturm.cc derive.cc desolve.cc ezgcd.cc freeglut_stroke_roman.c gauss.cc gausspol.cc gen.cc
  global.cc help.cc identificateur.cc ifactor.cc index.cc input_lexer.cc input_parser.cc intg.cc intgab.cc isom.cc
  lin.cc maple.cc mathml.cc misc.cc modfactor.cc modpoly.cc moyal.cc opengl.cc pari.cc permu.cc plot.cc plot3d.cc
  prog.cc quater.cc risch.cc rpn.cc series.cc solve.cc sparse.cc subst.cc sym2poly.cc symbolic.cc tex.cc threaded.cc
  ti89.cc tinymt32.cc TmpFGLM.cpp TmpLESystemSolver.cpp unary.cc usual.cc vecteur.cc)
list(TRANSFORM GIAC_FICHIERS PREPEND ${G}/)

add_library(fikajiana_giac SHARED ${GIAC_FICHIERS} fikajiana_giac.cc)

target_include_directories(fikajiana_giac BEFORE PRIVATE ${PREFIXE}/include ${GIAC_SOURCES_DIR}/src/giac/headers)

# Définitions du build Android de Giac (build.gradle) et de son CMakeLists.txt, sans pthread :
# Giac s'en sert pour annuler un calcul par pthread_cancel, absent de Bionic (docs/recherche/spike-giac.md).
# Sans SMARTPTR64 : il efface les bits hauts des pointeurs, où Android 11+ met une étiquette sur arm64.
target_compile_definitions(fikajiana_giac PRIVATE
  IN_GIAC GIAC_GGB GIAC_GENERIC_CONSTANTS HAVE_NO_HOME_DIRECTORY TIMEOUT NO_BSD PIC
  HAVE_UNISTD_H HAVE_SYSCONF HAVE_SYS_TIMES_H HAVE_SYS_TIME_H HAVE_LIBMPFR
  FIKAJIANA_SANS_SMARTPTR64 DOUBLEVAL SIZEOF_LONG=8 SIZEOF_VOID_P=8 VERSION="1.2.3")

target_compile_options(fikajiana_giac PRIVATE -O2 -fexceptions -frtti -fno-strict-aliasing -fPIC -w
  $<$<COMPILE_LANGUAGE:CXX>:-std=gnu++11>)

# MPFR avant GMP, comme le demande Giac.
target_link_libraries(fikajiana_giac PRIVATE ${PREFIXE}/lib/libmpfr.a ${PREFIXE}/lib/libgmp.a log)
target_link_options(fikajiana_giac PRIVATE -s -Wl,--gc-sections -Wl,-z,max-page-size=16384)
