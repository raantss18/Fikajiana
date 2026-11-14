// Seul script du site. Sans lui, tout reste lisible : l'empreinte se sélectionne à la main, la vidéo garde ses commandes.

// Le bouton « Copier » de l'empreinte du fichier.
(function () {
  var bouton = document.getElementById('copier');
  var texte = document.getElementById('empreinte');
  if (!bouton || !texte || !navigator.clipboard) return;
  bouton.hidden = false;
  bouton.addEventListener('click', function () {
    navigator.clipboard.writeText(texte.textContent.trim()).then(function () {
      bouton.textContent = 'Copié';
      setTimeout(function () { bouton.textContent = 'Copier'; }, 2000);
    });
  });
})();

// Les chapitres de la vidéo : un bouton place la lecture sur son passage.
(function () {
  var video = document.querySelector('#demo video');
  if (!video) return;
  document.querySelectorAll('#demo .chapitres button').forEach(function (b) {
    b.addEventListener('click', function () {
      video.currentTime = parseFloat(b.dataset.t);
      video.play();
    });
  });
})();
