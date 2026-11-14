// Interface C minimale de Giac pour dart:ffi.
#include "giac.h"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>

namespace {
// Au-delà, le résultat ne tient ni sur la feuille ni dans la mémoire du téléphone (audit 2026-11-14).
const int kFactorielleMax = 2000;
const size_t kBitsEntierMax = 200000; // environ 60 000 chiffres
const size_t kSortieMax = 400000;     // caractères

char *rendre(const std::string &sortie) {
  char *copie = strdup(sortie.c_str());
  return copie ? copie : strdup("ERREUR: mémoire");
}

bool tropGrand(const giac::gen &g) {
  return g.type == giac::_ZINT && mpz_sizeinbase(*g._ZINTptr, 2) > kBitsEntierMax;
}
} // namespace

extern "C" {

// Évalue une expression Giac et rend le résultat, à libérer avec fikajiana_giac_liberer.
// Une erreur de Giac rend une chaîne commençant par « ERREUR: ».
__attribute__((visibility("default"))) char *fikajiana_giac_eval(const char *entree) {
  static giac::context contexte;
  giac::FACTORIAL_SIZE_LIMIT = kFactorielleMax;
  std::string sortie;
  try {
    giac::gen expression(entree, &contexte);
    giac::gen resultat = giac::eval(expression, 1, &contexte);
    sortie = tropGrand(resultat) ? std::string("ERREUR: trop grand") : resultat.print(&contexte);
  } catch (const std::exception &erreur) {
    sortie = std::string("ERREUR: ") + erreur.what();
  } catch (...) {
    // Giac lance aussi des valeurs qui ne sont pas des std::exception : rien ne doit traverser la FFI.
    sortie = "ERREUR: inconnue";
  }
  return rendre(sortie);
}

// Calcule et rend « exact␟latex␟approché » (séparateur 0x1F). « ARRET » si le calcul a été interrompu.
// degres : angles en degrés (mode 1 de Giac) plutôt qu'en radians (mode 0).
__attribute__((visibility("default"))) char *fikajiana_giac_calculer(const char *entree, int degres) {
  static giac::context contexte;
  giac::angle_mode(degres ? 1 : 0, &contexte);
  // sin(x)=0 a une infinité de solutions : Giac n'en rend sinon que deux.
  giac::all_trig_sol(true, &contexte);
  giac::ctrl_c = false;
  giac::interrupted = false;
  giac::FACTORIAL_SIZE_LIMIT = kFactorielleMax;
  std::string sortie;
  try {
    giac::gen expression(entree, &contexte);
    giac::gen resultat = giac::eval(expression, 1, &contexte);
    if (giac::ctrl_c || giac::interrupted) {
      sortie = "ARRET";
    } else if (tropGrand(resultat)) {
      sortie = "ERREUR: trop grand";
    } else {
      sortie = resultat.print(&contexte);
      sortie += '\x1f';
      sortie += giac::gen2tex(resultat, &contexte);
      sortie += '\x1f';
      giac::gen approche = giac::evalf(resultat, 1, &contexte);
      // Une valeur, ou les solutions d'une équation, si elles sont toutes numériques.
      bool numerique = approche.type == giac::_DOUBLE_ || approche.type == giac::_REAL;
      if (approche.type == giac::_VECT && !approche._VECTptr->empty()) {
        numerique = true;
        for (const giac::gen &valeur : *approche._VECTptr) {
          numerique = numerique && (valeur.type == giac::_DOUBLE_ || valeur.type == giac::_REAL);
        }
      }
      if (numerique) {
        sortie += approche.print(&contexte);
      }
    }
  } catch (const std::exception &erreur) {
    sortie = (giac::ctrl_c || giac::interrupted) ? std::string("ARRET") : std::string("ERREUR: ") + erreur.what();
  } catch (...) {
    sortie = (giac::ctrl_c || giac::interrupted) ? "ARRET" : "ERREUR: inconnue";
  }
  if (sortie.size() > kSortieMax) {
    sortie = "ERREUR: trop grand";
  }
  giac::ctrl_c = false;
  giac::interrupted = false;
  return rendre(sortie);
}

// Demande l'arrêt du calcul en cours. Giac teste ce drapeau dans ses boucles, pas dans GMP.
__attribute__((visibility("default"))) void fikajiana_giac_interrompre() {
  giac::ctrl_c = true;
  giac::interrupted = true;
}

__attribute__((visibility("default"))) void fikajiana_giac_liberer(char *chaine) { free(chaine); }
}
