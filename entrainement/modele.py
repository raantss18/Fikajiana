"""Le petit réseau convolutif : image 32×32 et K mesures du tracé → logits des classes."""

from __future__ import annotations

import pathlib

import torch
from torch import nn


def _bloc(entree, sortie):
    return [nn.Conv2d(entree, sortie, 3, padding=1), nn.BatchNorm2d(sortie), nn.ReLU(inplace=True)]


class Reseau(nn.Module):
    """conv3×3(32)×2-pool · conv3×3(64)×2-pool · conv3×3(128)-pool · fc(128) avec les mesures."""

    def __init__(self, classes: int, k: int):
        super().__init__()
        self.image = nn.Sequential(
            *_bloc(1, 32), *_bloc(32, 32), nn.MaxPool2d(2),
            *_bloc(32, 64), *_bloc(64, 64), nn.MaxPool2d(2),
            *_bloc(64, 128), nn.MaxPool2d(2),
            nn.Flatten(),
        )
        self.mesures = nn.Sequential(nn.Linear(k, 32), nn.ReLU(inplace=True))
        self.tete = nn.Sequential(
            nn.Dropout(0.3),
            nn.Linear(128 * 4 * 4 + 32, 128),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(128, classes),
        )

    def forward(self, image, mesures):
        return self.tete(torch.cat([self.image(image), self.mesures(mesures)], dim=1))


def exporter_onnx(modele: Reseau, k: int, chemin: pathlib.Path) -> None:
    """ONNX : entrées `image` [N,1,32,32] et `mesures` [N,K] (float32), sortie `logits` [N,C]."""
    modele = modele.eval()
    exemple = (torch.zeros(1, 1, 32, 32), torch.zeros(1, k))
    torch.onnx.export(
        modele,
        exemple,
        str(chemin),
        input_names=["image", "mesures"],
        output_names=["logits"],
        dynamic_axes={"image": {0: "n"}, "mesures": {0: "n"}, "logits": {0: "n"}},
        opset_version=17,
        dynamo=False,
    )
