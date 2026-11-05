// Interface C minimale de Giac pour dart:ffi.
#include "giac.h"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>

extern "C" {

// Évalue une expression Giac et rend le résultat, à libérer avec fikajiana_giac_liberer.
// Une erreur de Giac rend une chaîne commençant par « ERREUR: ».
__attribute__((visibility("default"))) char *fikajiana_giac_eval(const char *entree) {
  static giac::context contexte;
  std::string sortie;
  try {
    giac::gen expression(entree, &contexte);
    sortie = giac::eval(expression, 1, &contexte).print(&contexte);
  } catch (const std::exception &erreur) {
    sortie = std::string("ERREUR: ") + erreur.what();
  }
  return strdup(sortie.c_str());
}

__attribute__((visibility("default"))) void fikajiana_giac_liberer(char *chaine) { free(chaine); }
}
