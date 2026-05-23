Dies ist eine eingens von mir erstellte 3D-Spielengine, welche sich noch in Entwicklung befindet.
Die Grundrisse mit der Windows-API wurden mit Hilfe vom Handmade Hero Projekt, welches in C++ geschrieben wurde, erstellt.

Features:
-Darstellung der Pixel basierend auf der Kollision eines Strahls mit den Dreiecken der Umgebung
-Steuerung das Spielers mit WASD, Space (oben) und Shift (unten)
-Umsehen ist Möglich mit der Maus.
-Rohdaten der Maus werden abgegriffen und der Cursor wird im Fenster eingesperrt
-Optimiere darstellung der Formen (bisher haben Formen ungewollte Rundungen durch die Berechnung der Strahlen)
-Timing/Benchmarking einrichten für einzelne Funktionen
->etwa 21ms pro frame
-Optimierung durch Bounding Boxen und Culling

Gesplante Features:
-Optimierung durch Multithreading
-Optimierung durch SIMD
-Darstellung von Texturen
-FOV-Anpassung durch Geschwindigkeitsveränderungen
-Pause Menü
-Multiplayer Support
-2D Font Rendering
-Gravitation
-Kollision

