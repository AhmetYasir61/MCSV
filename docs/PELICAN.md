# Debian + Pelican Panel'e kurulum

Pelican Panel'de sunucu dosyaları paneli değil **Wings** düğümünü barındıran
makinede durur. Varsayılan konum:

```
/var/lib/pelican/volumes/<sunucu-uuid>/
```

`<sunucu-uuid>` panelde sunucunun ayarlar sayfasında yazar (Settings > Server ID /
UUID; kısa ID değil, uzun olan). Wings farklı bir dizin kullanıyorsa:

```bash
grep -A3 '^system:' /etc/pelican/config.yml     # data / volume yolu burada
```

## Otomatik yol

Wings makinesinde, **sunucu panelden durdurulduktan sonra**:

```bash
sudo ./scripts/deploy_pelican.sh --uuid 1a2b3c4d-... --world out/GoT-World
```

Betik ne yapıyor:

1. `level.dat` var mı diye bakıp yanlış klasörü kopyalamayı engeller
2. Varsa eski dünyayı `world.bak-<tarih>` olarak yedekler
3. Dünyayı `<volume>/world` içine kopyalar (`--level-name` ile ad değiştirilir)
4. `server.properties` içinde `level-name` değerini ayarlar
5. Sahipliği **volume dizininden okuyup** aynısını uygular

Beşinci madde önemli: Wings konteynerleri kendi uid/gid'iyle çalışır (çoğunlukla
`988:988`, ama sürüme göre değişir). Sabit değer yazmak yerine mevcut volume
dizininin sahipliği örnek alınır; yanlış sahiplik sunucunun dünyayı açamamasına
(`permission denied`, "failed to load level.dat") yol açar.

Önce ne yapacağını görmek için: `--dry-run`.

## Elle yol

```bash
# 1) Sunucuyu panelden durdurun
VOL=/var/lib/pelican/volumes/1a2b3c4d-...
sudo mv $VOL/world $VOL/world.old
sudo rsync -a out/GoT-World/ $VOL/world/
sudo sed -i 's|^level-name=.*|level-name=world|' $VOL/server.properties
sudo chown -R $(stat -c '%u:%g' $VOL) $VOL/world
# 2) Panelden başlatın
```

## SFTP ile (Wings makinesine SSH erişimi yoksa)

Panel her sunucu için bir SFTP hesabı verir (Settings > SFTP Details). Port
genelde 2022'dir:

```bash
sftp -P 2022 <kullanici>.<kisa-id>@<sunucu-adresi>
> put -r out/GoT-World world
```

Bu yolda sahiplik zaten doğru olur, ancak yüzlerce GB'lık bir dünya için SFTP
çok yavaştır; büyük dünyalarda diske doğrudan kopyalama tercih edilir.

## Dünya boyutu ve disk

Panelde sunucuya tanımlı **disk limiti** dünyadan büyük olmalı, yoksa Wings
sunucuyu başlatmayı reddeder. Ölçek başına kabaca beklenen boyut için
[SCALE.md](SCALE.md) tablosuna bakın; `--scale 16` (16.000 x 16.000 blok) için
~20 GB civarı ayırmak makul bir başlangıçtır.

Sunucu tipi olarak Paper önerilir: chunk yükleme hızı ve BlueMap eklenti desteği
için en pratik seçenek.

## Sınır dışına vanilla üretimi engellemek

WorldPainter dünyası sonlu; oyuncular kenardan çıkarsa vanilla arazi üretilir ve
harita kenarında çirkin bir sınır oluşur. İki çözüm:

```
# server.properties
max-world-size=<yarıçap>          # blok cinsinden, dünyanın yarısı
```

ya da WorldBorder / Paper'ın kendi sınır komutu:

```
/worldborder center 0 0
/worldborder set 32000
```

## BlueMap'i aynı panelde çalıştırmak

`BlueMap-*.jar` dosyasını sunucunun `plugins/` klasörüne koyup bir kez başlatın,
sonra `plugins/BlueMap/core.conf` içinde `accept-download: true` yapın. Web
arayüzü için panelde ek bir port ayırmanız (Network > Allocations) ve
`plugins/BlueMap/webserver.conf` içinde o portu yazmanız gerekir. Ayrıntı ve
CLI ile sunucusuz render seçeneği: [VIEWER.md](VIEWER.md).
