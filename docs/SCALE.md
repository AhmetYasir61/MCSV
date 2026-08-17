# Ölçek gerçekliği: 1.000.000 x 1.000.000 blok neden çıkmıyor?

Kısa cevap: dünya **üretilebilir** ama **saklanamaz** ve hele GitHub'a hiç konulamaz.
Aşağıdaki hesap, deponun neden "dünya dosyası" değil "dünya üreteci" içerdiğini açıklıyor.

## Ham sayılar

| Büyüklük | Değer |
|---|---|
| Yüzey sütunu (blok kolonu) | 1.000.000 x 1.000.000 = **10¹²** |
| Chunk (16x16) | 3.906.250.000 (~3,9 milyar) |
| Region dosyası (512x512) | 3.814.697 |
| Blok hacmi (Y = -64..319, 384 kat) | **3,84 x 10¹⁴** |

## Disk

Tam üretilmiş, sıkıştırılmış bir chunk pratikte 5–80 KB arasında yer kaplar
(su/düz arazi altta, mağaralı ve dekorlu arazi üstte).

| Chunk başına | Toplam dünya |
|---|---|
| 5 KB (en iyimser, çoğu okyanus) | ~19 TB |
| 20 KB (tipik) | ~78 TB |
| 40 KB (dekorlu arazi) | ~156 TB |

GitHub tarafındaki sınırlar: dosya başına 100 MB (hard limit), depo başına
önerilen üst sınır 1–5 GB, Git LFS kotaları da bunun çok altında. Yani 19 TB'lık
en iyimser senaryo bile GitHub'ın **dört kat büyüklük mertebesi** üzerinde.

## Süre

Kaliteli bir üretim hattı (WorldPainter export ya da Chunky/pre-generator)
tek makinede kabaca 300–2000 chunk/saniye üretir.

3,9 milyar chunk / 1000 chunk/sn ≈ **45 gün kesintisiz üretim**.

## Oyun tarafı

- Minecraft dünya sınırı ±29.999.984 blok, yani 1.000.000 x 1.000.000 teknik
  olarak sığar — sorun sınır değil, depolama.
- Bir sunucuda oynanabilirlik için chunk'ların diskte hazır olması gerekir;
  20 TB'lık bir dünyayı barındıran VPS aylık maliyeti dört haneli dolar.

## Bunun yerine ne yapılıyor?

Ölçek, `mapgen.py --scale` ile serbest. Kaynak harita 1000x1000 piksel varsayımıyla:

| `--scale` | Dünya boyutu | Chunk | Kabaca disk (20 KB/chunk) | Durum |
|---|---|---|---|---|
| 8 | 8.000 x 8.000 | 250 bin | ~5 GB | tek makinede rahat |
| 16 | 16.000 x 16.000 | 1 milyon | ~20 GB | önerilen başlangıç |
| 32 | 32.000 x 32.000 | 4 milyon | ~80 GB | ciddi sunucu |
| 64 | 64.000 x 64.000 | 16 milyon | ~320 GB | uzun üretim |
| 1000 | 1.000.000 x 1.000.000 | 3,9 milyar | ~78 TB | pratikte imkânsız |

Karşılaştırma: yıllardır elle inşa edilen **WesterosCraft** projesinin haritası
kabaca 60.000 x 40.000 blok mertebesindedir; yani yukarıdaki tablodaki 32–64
aralığı zaten "1:1 Westeros" iddiasının gerçek karşılığıdır.

## Depo ne içeriyor?

Dünyanın kendisi değil, **onu üreten tarif**: renk paleti, yükseklik/biome
üretici (`tools/mapgen.py`) ve WorldPainter içe aktarma betiği. Bu birkaç yüz KB
Git'te durur, çıktı ise kullanıcının kendi diskinde istenen ölçekte üretilir.
