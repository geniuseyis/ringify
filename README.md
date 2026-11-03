# Ringify

03.11.2026 güncel durum: webde **390 test ve üretim derlemesi başarılı**. Swift kaynaklarında **116 dosyalık sözdizimi kontrolü** geçti; native SDK/derleme/cihaz testleri henüz doğrulanmadı. [Güncel ilerleme](PROGRESS.md) ve [son kaynak paketi](docs/NATIVE_COMPARISON_AND_SLOTS.md) esas alınır. Depoya ilk aktarım dört güne bölünmektedir; ara commit'ler ve ilk günün dosya kümesi tam uygulama teslimi değildir. [Aktarım planı](docs/GITHUB_DELIVERY_PLAN.md).

Ringify, kullanıcının sahip olduğu ses veya video dosyasından 1–29 saniyelik bir bölüm seçip yerel olarak düzenlemesini ve iPhone zil sesi akışına hazırlamasını amaçlayan, çevrimdışı öncelikli bir iPhone uygulamasıdır. Ana vaat: **“Kendi video veya sesinden saniyeler içinde kişiselleştirilmiş iPhone zil sesi oluştur.”**

Bu depo iki ayrı teslimatı birlikte taşır:

- `ios/`: macOS ve Xcode üzerinde derlenmek üzere tasarlanan gerçek Swift 6 / SwiftUI uygulaması.
- `preview/`: Windows’ta çalışabilen React + TypeScript etkileşimli ürün önizlemesi. Bu önizleme iOS uygulamasının yerine geçmez.
- `packages/RingifyCore/`: platformdan bağımsız modeller, iş kuralları ve doğrulamalar için Swift paketi.
- `design/`: iki istemcinin paylaşacağı tasarım tokenlarının kaynak dosyası.

## Durum sözlüğü

Tüm özellik tablolarında yalnızca aşağıdaki ürün durumları kullanılır:

| Durum | Anlamı |
| --- | --- |
| `IMPLEMENTED_AND_TESTED` | Uygulama tamamlandı ve ilgili ortamda test başarıyla çalıştırıldı. |
| `IMPLEMENTED_NOT_TESTED` | Kaynak kod mevcut; ilgili platform testi henüz çalıştırılmadı. |
| `DEMO_ONLY` | Yalnızca web önizlemesinde örnek/simülasyon olarak bulunuyor; yerel iOS işlevi sayılmaz. |
| `NOT_IMPLEMENTED` | İşlev henüz uygulanmadı. |
| `BLOCKED_BY_MACOS` | Uygulama veya doğrulama için macOS, Xcode, iOS Simulator ya da gerçek iPhone gerekiyor. |

`NOT_TESTED`, test planında kullanılan bir **test sonucu** ifadesidir; yukarıdaki özellik durum sözlüğüne yeni bir durum eklemez.

Güncel ayrıntılar için [Özellik Matrisi](docs/FEATURE_MATRIX.md) ve [Teknik Sınırlamalar](docs/TECHNICAL_LIMITATIONS.md) belgelerine bakın.

## İlk teslimin tarihsel özeti

1. **Oluşturulan yapı:** Kök belgeler, `docs/` ürün/teknik paketi, ortak tasarım tokenları, `preview/`, `packages/RingifyCore/` ve `ios/` kaynak ağaçları bulunuyor.
2. **Windows komutları:** Önizleme için `npm.cmd install`, `npm.cmd run dev`, `npm.cmd run test` ve `npm.cmd run build` kullanılır.
3. **Yerel adres:** Geliştirme sunucusu `http://127.0.0.1:5173/` adresinde başlatıldı; HTTP 200 ve sayfa başlığı doğrulandı. Sonraki çalıştırmada port doluysa Vite farklı adres seçebilir.
4. **Ekran kapsamı:** 14 ekranın web ve SwiftUI kaynak karşılıkları bulunuyor. Native ekranların kaynakta bulunması Xcode’da derlendiği anlamına gelmez.
5. **Gerçek işlev kaynakları:** Web production build ve 4 dosyada 7/7 otomatik test geçti; Home → Import, tema değişimi, kurtarılabilir decode hatası, klavyeyle waveform sınırları, WAV encoder ve format yardımcıları doğrulandı. Native import/audio/export/storage/purchase kaynakları Mac’te test edilmedi.
6. **Demo/simülasyon:** Web localStorage kütüphanesi, Pro bayrağı, StoreKit temsili, native Share Sheet ve zil sesi rehberi iOS sahipliği/işlevi sayılmaz; ilgili satırlar `DEMO_ONLY` olarak ayrılır.
7. **Uygulanmayanlar:** Yetkisiz platform indirme, üretim uzak host entegrasyonu, üçüncü taraf uygulamadan sistem ayarını programatik değiştirme ve üretim App Store kurulumu yoktur.
8. **Test sonucu:** `npm.cmd run build` ve `npm.cmd run test` `PASS`; 7/7 test geçti. Mevcut Windows’ta Swift/iOS testleri `NOT_TESTED`; macOS/Xcode gerektiren kabul `BLOCKED_BY_MACOS`.
9. **Mac/Xcode kapıları:** Swift 6 compile, XcodeGen üretimi, AVFoundation codec/export, SwiftData migration, StoreKit sandbox, VoiceOver ve gerçek cihaz izin/audio session akışları doğrulanmalıdır.
10. **App Store öncesi:** Signing, App Store Connect/IAP, üretim Privacy/Support/Terms URL’leri, gerçek cihaz görselleri, TestFlight, erişilebilirlik ve review checklist tamamlanmalıdır.

## Teknolojiler

- iOS: Swift 6, SwiftUI, Swift Concurrency, AVFoundation, PhotosUI, SwiftData ve StoreKit 2.
- Çekirdek: Swift Package Manager ile `RingifyCore`.
- Windows önizleme: React, TypeScript, Vite, Lucide ve desteklenen yerlerde Web Audio API.
- Tasarım: semantik sistem renkleri, Dynamic Type yaklaşımı, SF Symbols (yalnız iOS), Lucide (web) ve paylaşılmış tokenlar.
- Mimari: MVVM + Domain + Service Layer; protokol tabanlı bağımlılık enjeksiyonu.

## Windows’ta çalıştırma

Bu çalışma alanında 31 Ekim 2026 tarihinde yapılan araç kontrolünde Node.js `v24.11.1` ve npm `11.6.2` bulundu; `swift`, `xcodebuild` ve `xcodegen` bulunamadı. Dolayısıyla bu Windows makinesinde iOS derlemesi, Swift testi, Simulator testi veya gerçek iPhone testi yapıldığı iddia edilmez. Kurulum sırasında jsdom 30’un bazı geçişli paketleri Node engine uyarısı verdi; build ve test yine geçti. Yeni kurulum için Node `^24.15` veya `^22.22.2` önerilir.

PowerShell betik çalıştırma ilkesi `npm.ps1` dosyasını engelleyebildiği için aşağıdaki örnekler `npm.cmd` kullanır:

```powershell
cd .\preview
npm.cmd install
npm.cmd run dev
```

Bu teslimatta Vite `http://127.0.0.1:5173/` adresinde HTTP 200 ile doğrulandı. Yeni çalıştırmada terminalin bildirdiği adresi açın; port doluysa Vite farklı bir port seçebilir.

Üretim derlemesi ve web testleri:

```powershell
cd .\preview
npm.cmd run build
npm.cmd run test
```

Doğrulanmış Windows sonucu:

- `npm.cmd install`: tamamlandı; 105 paket denetlendi, 0 güvenlik açığı.
- `npm.cmd run build`: `PASS`; Vite 8.3.5, 2062 modül, `dist/` üretildi.
- `npm.cmd run test`: `PASS`; 4 test dosyası, 7/7 test, yaklaşık 2,30 saniye.
- Headless Edge smoke: splash ve onboarding görsel olarak açıldı; incelenen görüntülerde taşma görülmedi.

Önizlemedeki dosya seçimi, tarayıcının desteklediği ses biçimleriyle sınırlıdır. Tarayıcıda gerçek M4A/AAC zil sesi dışa aktarımı veya iOS Share Sheet taklit edilmez; bu tür eylemler açıkça demo ya da iOS’a özgü olarak etiketlenmelidir.

## Swift testleri

Swift 6 araç zinciri bulunan bir ortamda:

```powershell
cd .\packages\RingifyCore
swift test
```

Bu komut mevcut Windows makinesinde `swift` yüklü olmadığı için çalıştırılamaz. Paket kaynaklarının bulunması testlerin geçtiği anlamına gelmez. Ayrıntılı senaryolar [Test Planı](docs/TEST_PLAN.md) içindedir.

## macOS ve Xcode kurulumu

1. Güncel macOS üzerinde Xcode ve Command Line Tools’u kurun.
2. Depoyu Mac’e kopyalayın; `packages/RingifyCore` içinde önce `swift test` çalıştırın.
3. Depoda `project.yml` bulunuyorsa [XcodeGen](https://github.com/yonaskolb/XcodeGen) kurup depo kökünde `xcodegen generate` çalıştırın ve üretilen `.xcodeproj` dosyasını açın.
4. `project.yml` yoksa Xcode’da iOS App hedefi oluşturun; `ios/Ringify` kaynaklarını hedefe ekleyin ve `RingifyCore` paketini yerel paket bağımlılığı olarak bağlayın.
5. Bundle identifier, signing team, `NSMicrophoneUsageDescription`, desteklenen belge türleri, StoreKit konfigürasyonu ve deployment target değerlerini doğrulayın.
6. Bir iOS 17+ Simulator üzerinde derleyin; cihaz ve sürüm koşullu iOS 26 davranışları için availability kontrollerini gözden geçirin.

Kesin dosya/hedef düzeni için [Mimari](docs/ARCHITECTURE.md) belgesini izleyin.

## Gerçek iPhone’da doğrulama

1. Geliştirici imzalama ayarlarıyla uygulamayı fiziksel iPhone’a kurun.
2. Fotoğraflar, Dosyalar ve mikrofon kaynaklarını ayrı ayrı deneyin; yalnız gerektiğinde izin istendiğini kontrol edin.
3. Ses içermeyen video, bozuk dosya, desteklenmeyen codec ve yetersiz depolama yollarını çalıştırın.
4. 1 saniye ve 29 saniye sınırlarında kesme, oynatma, fade, ses seviyesi, iptal ve arka plan davranışını kontrol edin.
5. M4A/AAC çıktısının gerçekten oluştuğunu, boş olmadığını, oynatılabildiğini ve süresinin seçime uyduğunu doğrulayın.
6. StoreKit Configuration ve sandbox hesabıyla satın alma, iptal, hata ve geri yükleme yollarını sınayın.
7. VoiceOver, Dynamic Type, koyu/açık tema, Increase Contrast ve Reduce Motion ile tüm ana akışı tamamlayın.

### iOS 26 zil sesi akışı uyarısı

Bazı güncel App Store ürün açıklamaları iOS 26 Share Sheet içinde “Use as Ringtone” seçeneğini bildiriyor. Apple’ın herkese açık destek belgesi ise doğrulanabilir genel yöntem olarak hâlâ [GarageBand ile özel zil sesi oluşturma](https://support.apple.com/en-us/120692) akışını anlatıyor. Üçüncü taraf bir uygulamanın sistem zil sesini sessizce veya doğrudan değiştirebildiği varsayılmaz.

- Özellik durumu: `BLOCKED_BY_MACOS`
- Gerçek cihaz test sonucu: `NOT_TESTED`

Ringify çıktıyı paylaşır, iOS’un sunduğu eylemleri gösterir ve bulunmayan bir sistem eylemini vaat etmez. iOS 26 doğrudan akışı ancak desteklenen gerçek cihazda görülüp uçtan uca doğrulandıktan sonra tamamlanmış sayılabilir; eski sürümlerde GarageBand rehberi korunur.

## Ürün kapsamı

Planlanan ana akış: **İçe aktar → Doğrula → Analiz et → Düzenle → Ön dinle → Dışa aktar → Doğrula → Kaydet/Paylaş**.

Kapsam:

- Fotoğraflar’dan video, Dosyalar’dan ses/video ve mikrofon kaydı.
- Gerçek waveform, 1–29 saniye seçim, oynatma, yakınlaştırma, undo/redo ve sıfırlama.
- Ses seviyesi, fade-in, fade-out; yalnız güvenilir uygulama varsa normalize.
- Yerel proje kütüphanesi ve M4A/AAC dışa aktarım doğrulaması.
- Türkçe varsayılan arayüz ve İngilizce yerelleştirme.
- Tek seferlik, non-consumable Ringify Pro ürünü; fiyat yalnız StoreKit’ten gelir.
- Hesapsız ve temel işlevlerde çevrimdışı kullanım.

Kapsam dışı:

- YouTube, TikTok veya Instagram’dan yetkisiz indirme; DRM aşma.
- Bir üçüncü taraf uygulamasından sistem zil sesini programatik olarak zorla değiştirme.
- Uygulanmamış AI efektlerini, codec desteğini veya satın alma sonucunu varmış gibi gösterme.
- İlk sürümde zorunlu sunucu, kullanıcı hesabı, izleme SDK’sı veya ücretli API.

## Belge dizini

- [Ürün Gereksinimleri](docs/PRD.md)
- [HIG Tasarım Kararları](docs/HIG_DESIGN_DECISIONS.md)
- [Rakip Analizi](docs/COMPETITOR_ANALYSIS.md)
- [Ekran Özellikleri](docs/SCREEN_SPECIFICATIONS.md)
- [Mimari](docs/ARCHITECTURE.md)
- [Özellik Matrisi](docs/FEATURE_MATRIX.md)
- [Teknik Sınırlamalar](docs/TECHNICAL_LIMITATIONS.md)
- [Test Planı](docs/TEST_PLAN.md)
- [App Store Kontrol Listesi](docs/APP_STORE_CHECKLIST.md)
- [Yol Haritası](docs/ROADMAP.md)

## Temel resmî kaynaklar

- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [HIG JSON ana indeksi](https://developer.apple.com/tutorials/data/design/human-interface-guidelines.json)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple SF Symbols](https://developer.apple.com/sf-symbols/)
- [Apple: GarageBand ile özel zil sesi oluşturma](https://support.apple.com/en-us/120692)

