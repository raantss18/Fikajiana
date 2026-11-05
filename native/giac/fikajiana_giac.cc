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

// Calcule et rend « exact␟latex␟approché » (séparateur 0x1F). « ARRET » si le calcul a été interrompu.
__attribute__((visibility("default"))) char *fikajiana_giac_calculer(const char *entree) {
  static giac::context contexte;
  giac::ctrl_c = false;
  giac::interrupted = false;
  std::string sortie;
  try {
    giac::gen expression(entree, &contexte);
    giac::gen resultat = giac::eval(expression, 1, &contexte);
    if (giac::ctrl_c || giac::interrupted) {
      sortie = "ARRET";
    } else {
      sortie = resultat.print(&contexte);
      sortie += '\x1f';
      sortie += giac::gen2tex(resultat, &contexte);
      sortie += '\x1f';
      giac::gen approche = giac::evalf(resultat, 1, &contexte);
      if (approche.type == giac::_DOUBLE_ || approche.type == giac::_REAL) {
        sortie += approche.print(&contexte);
      }
    }
  } catch (const std::exception &erreur) {
    sortie = (giac::ctrl_c || giac::interrupted) ? std::string("ARRET") : std::string("ERREUR: ") + erreur.what();
  }
  giac::ctrl_c = false;
  giac::interrupted = false;
  return strdup(sortie.c_str());
}

// Demande l'arrêt du calcul en cours. Giac teste ce drapeau dans ses boucles, pas dans GMP.
__attribute__((visibility("default"))) void fikajiana_giac_interrompre() {
  giac::ctrl_c = true;
  giac::interrupted = true;
}

__attribute__((visibility("default"))) void fikajiana_giac_liberer(char *chaine) { free(chaine); }
}
