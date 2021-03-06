# Statistics

Notes:
Model 3 has superior speed compared to Model 2 with only
a small cost in extra memory usage so should be preferred.

## Models

### Model 1

Stores one byte per voxel

### Model3

Stores 1 bit per voxel so the voxel is either solid or air.


## GPU Memory Usage (MB)

Scene |  M1  |  M2  |  M3  |  M4  |  M5  |  M6
------|------|------|------|------|------|------
  1   |   2  |   0  |   0  |   2  |      |
  2   |   5  |   0  |   2  |  14  |      |
  3   |   8  |   1  |   5  |  28  |      |
  4   | 242  | 247  | 286  | 425  |      |
  4b  |  54  |  46  |  56  |  81  |      |
  4c  |  79  |  59  |  68  |  87  |      |
  5   |   2  |   1  |   1  |   1  |      |
  6   |  53  |  41  |  42  |  36  |      |
  7   |  32  |  28  |  31  | 243  |      |
  8   |   1  |   0  |   1  |   1  |      |

## Frames Per Second (1200x800)

### RX 470

Scene |   M1  |  M2  |  M3  |  M4  |  M5  |  M6
------|-------|------|------|------|------|------
  1   |  768  |  862 |  940 |  900 |      |
  2   | 1190  | 1380 | 1440 | 1405 |      |
  3   |  356  |  458 |  544 |  453 |      |
  4   |  317  |  397 |  430 |  370 |      |
  4b  |  297  |  382 |  413 |  375 |      |
  4c  |  284  |  366 |  395 |  373 |      |
  5   |  980  | 1124 | 1185 | 1095 |      |
  6   |  575  |  725 |  780 |  722 |      |
  7   |  390  |  455 |  498 |  488 |      |
  8   |  523  |  662 |  702 |  674 |      |

### Laptop i7-1065G7 Iris Plus

Scene |   M1  |  M2  |  M3  |  M4  |  M5  |  M6
------|-------|------|------|------|------|------
  1   |  151  |      | 191  |      |      |
  2   |  247  |      | 287  |      |      |
  3   |  85   |      | 142  |      |      |
  4   |  76   |      | 97   |      |      |
  4b  |  74   |      | 98   |      |      |
  4c  |  69   |      | 93   |      |      |
  5   |  205  |      | 245  |      |      |
  6   |  139  |      | 176  |      |      |
  7   |  80   |      | 109  |      |      |
  8   |  121  |      | 158  |      |      |

### GTX 1660 (+900Mhz mem overclock + 100Mhz core overclock + distance field optimisation)

(OpenGL / Vulkan)

Scene |     (M1))    |  M2  |    (M3)     |  M4  |  M5  |  M6
------|-------------|------|-------------|------|------|------
  1   | 1274 / 1267 | 1295 | 1580 / 1670 | 1350 |      |
  2   | 1785 / 1940 | 2020 | 2400 / 2750 | 1950 |      |
  3   |  513 /  550 |  708 |  925 / 980  |  630 |      |
  4   |  422 /  422 |  530 |  608 / 625  |  474 |      |
  4b  |  432 /  437 |  540 |  625 / 650  |  528 |      |
  4c  |  395 /  394 |  515 |  591 / 604  |  494 |      |
  5   | 1635 / 1780 | 1660 | 1980 / 2230 | 1700 |      |
  6   |  868 /  904 | 1007 | 1175 / 1265 | 1000 |      |
  7   |  550 /  561 |  665 |  784 / 822  |  672 |      |
  8   |  907 /  960 | 1010 | 1175 / 1300 | 1077 |      | 500
