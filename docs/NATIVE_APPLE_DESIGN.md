# Ringify — native Apple tasarım sözleşmesi

Native SwiftUI ekranlarının görsel kuralları. Apple Human Interface Guidelines temel alınır.

Ürün: İnsanların video, ses veya mikrofon kaydından bölüm seçip efekt ekleyerek iPhone için en fazla 29 saniyelik kendi zil seslerini cihaz üzerinde oluşturduğu kişisel ses stüdyosu. Sıra: İçe Aktar → Stüdyoda Kes → Efektler → Ön İzleme → Dışa Aktar → Zil Sesi Olarak Ayarla.

## Düzeltilen gerçek sorunlar

Kanıt: `design/screenshots/native-ui/390x844` (çalışma `42032489487`).

| Sorun | Karar |
| --- | --- |
| Açık temada siyah kartlar (Home, Stüdyo, Pro) | Sistem yüzeyleri; koyu tuval yok |
| Dalga formu dolu mor blok: 240 örnek, örnek başına ~1,4 pt ama çubuk en az 1,5 pt, yani üst üste biniyor | `WaveformBars` ile örnek azaltma; birbirine değmeyen yuvarlak çubuklar |
| Home'da iki başlık, slogan, hero; projeler sekme çubuğunun altında | Büyük başlık, tek oluşturma kartı, liste |
| Her ikonun arkasında lila kutu | Kutusuz, tint'li SF Symbol |
| Kütüphane: "Koleksiyonl-ar" kelime kırılması, segment kontrolün ekran kenarına taşması, satırda hem ok hem "…" | Tek satırlık kaydırılabilir kontroller, doğru kenar boşluğu, satırda tek gösterge |
| Birbirini tekrar eden proje başlığı ve dekoratif zil/telefon kutuları | Kaldırıldı; içerik öne çıkar |
| Ana eylemin ekran dışında kalması (Pro, Önizleme, Efektler) | Eylem alt çubukta sabit |
| Eşit olmayan yükseklikte ızgara kartları (İçe Aktar, Yardım) | Standart gruplu liste |
| Sahte stiller: büyük harf kaşlık, `tracking`, özel kenarlıklar, gölgeler | Yalnız sistem metin stilleri ve yüzeyleri |

## İlkeler

Apple'ın üç ilkesi: **hiyerarşi** (kontroller içeriğin önüne geçmez, en önemli şey ilk bakışta belli olur), **uyum** (donanım ve yazılımla aynı biçim dili), **tutarlılık** (sistem kuralları, her boyutta aynı davranış).

1. **Önce sistem bileşeni.** `List`/`Form` (`.insetGrouped`), `Section`, `LabeledContent`, `Toggle`, `Slider`, `Picker`, `Menu`, `ContentUnavailableView`, `.searchable`, `.swipeActions`, `.contextMenu`, `.confirmationDialog`, `.sheet`. Özel çizim yalnız dalga formu editörü, kayıt düğmesi ve seviye göstergesi için.
2. **Tek ana eylem.** Ekran başına bir `ringifyPrimaryAction`; uzun içerikte `ringifyBottomBar` içinde sabit.
3. **Renk.** Yalnız sistem semantik renkleri ve tek marka vurgusu (`AccentColor`). Kırmızı yalnız kayıt ve silme, yeşil yalnız başarı.
4. **Tipografi.** Yalnız Dynamic Type metin stilleri. Süreler `.monospacedDigit()`.
5. **Liquid Glass.** Yalnız kontrol katmanında (`RingifyCircleButton`, ana eylem, sistem çubukları). İçerikte asla.
6. **Navigasyon.** Sekme kökleri büyük başlık, alt ekranlar `.inline`. Ok işareti yalnız gerçekten gezinen satırda.
7. **Dürüstlük.** Sahte dalga, sahte seviye, uydurma yüzde yok. Gerçek veri yoksa düz çizgi veya sembol.

## Yasaklar

Yeni kodda bulunmayacak: `RingifyTheme.Studio`, `RingifyTheme.AppleV2`, `ringifyStudioAppearance`, `ringifyVisualStyle`, `NativeContentCard`, `NativePrimaryAction`, `NativePrimaryActionLabel`, `NativePressButtonStyle`, `NativeProjectIdentity`, `.scrollContentBackground(.hidden)`, `.tracking(...)`, `.textCase(.uppercase)`, büyük harfle yazılmış metin, hex renk, `Color.black`/`Color.white` yüzey, kart çevresinde `strokeBorder`, `.shadow`, ikon arkasında kutu veya daire, `.tint(RingifyTheme.accent)` (genel vurgu zaten asset'ten gelir ve açık tint nötr düğmeleri lila yapar), `.font(.system(size:))` (yalnız `@ScaledMetric` ile). `RingifyTheme.brandGradient` yalnız `LaunchView`'da.

## Temel API

Dosyalar: `DesignSystem/RingifyTheme.swift`, `RingifyComponents.swift`, `NativePresentationComponents.swift`.

| API | Kullanım |
| --- | --- |
| `RingifyTheme.accent/action/success/warning/danger/record` | Marka ve durum renkleri |
| `RingifyTheme.background/surface/subtleFill` | Sayfa, grup yüzeyi, sessiz dolgu |
| `RingifyTheme.horizontalPadding` (16), `.cardRadius` | Liste ile aynı kenar ve köşe |
| `.ringifyPrimaryAction()` | Ana eylem; `Button`, `ShareLink`, `PhotosPicker`. Tam genişlik için etikete `.frame(maxWidth: .infinity)` |
| `.ringifySecondaryAction()` | Destek eylemi: nötr dolgu, vurgu etiket |
| `RingifyPrimaryButton(title:systemImage:isLoading:isDisabled:action:)` | Tam genişlik ana eylem. `title` `LocalizedStringKey`; değişken metin için `LocalizedStringKey(model.uiText(...))` |
| `.ringifyBottomBar { ... }` | Alt çubukta sabit kontroller |
| `.ringifyCard(padding:)` | Liste dışı özel içerik için grup yüzeyi |
| `RingifyCircleButton(title:systemImage:emphasis:diameter:isSelected:action:)` | Yuvarlak taşıma düğmesi; `title` VoiceOver etiketi (`String`) |
| `RingifyRow(_ title: Text, subtitle:systemImage:value:showsChevron:iconTint:)` | Standart liste satırı. `Text("anahtar")` veya `Text(model.uiText(...))` |
| `RingifyProjectLabel(project:detail:)` | Proje satırı: gerçek dalga küçük görseli, ad, süre · durum, favori |
| `RingifyWaveformThumbnail(samples:size:)`, `WaveformView(samples:tint:dimmedTint:selection:barWidth:barGap:)` | Gerçek dalga |
| `NativeSelectionWaveform(project:elapsed:height:)` | Seçim ve imleçle salt okunur dalga |
| `NativeMetadataRow(title:value:)` | Başlık + değer satırı (`String`) |
| `DurationText(seconds:)`, `DurationText.formatted(_:)`, `DurationText.ruler(_:)` | Süre biçimleri |
| `RingifyEmptyState`, `RingifyLoadingView` | Boş ve yükleniyor durumu |

## Ekranlar

**Sekme çubuğu:** Ana Sayfa, Stüdyo, Kütüphane, Ayarlar. Değişmez.

**Karşılama (`LaunchView`):** Kullanıcının seçtiği marka ekranı; değişmez. **Tanıtım (`OnboardingView`):** Yazıldı.

**Home (`HomeView`) — `List`, `.insetGrouped`, `.large` başlık "Ringify".** Araç çubuğunda taç (`home.pro`). İlk bölümde tek oluşturma kartı: `RingifyTheme.action.gradient` zeminli, beyaz metinli büyük satır: `plus.circle.fill`, "Yeni Zil Sesi Oluştur", "Video, ses veya mikrofon" (`home.create`). Yanlış yerleşmiş `signatureCard` metinleri, slogan, kaşlık, `HomeSignatureArtwork`, ikinci başlık ve ayar düğmesi kalkar. "Hızlı Erişim" bölümü: Ses Kaydet (`home.quick.record`), Ses Dönüştür (`home.quick.conversion`, `router.push(.conversion)`), Nasıl Ayarlanır? (`home.quick.guide`). Kütüphane kısayolu kalkar (sekme ile aynı). "Son Projeler" bölümü: başlığın sağında "Tümünü Gör" (`home.projects.all`), en fazla 3 `RingifyProjectLabel`. Boş durumda bölümde tek satır açıklama. Yükleniyorken `ProgressView`.

**Stüdyo (`AudioEditorView`) — `ScrollView`, zemin `RingifyTheme.background`, `.inline`.** Başlık proje adı; yoksa "Ses Stüdyosu". Araç çubuğunda geri al/ileri al. Sıra: (1) tek `ringifyCard`: üstte cetvel (`DurationText.ruler`, ilk etiket sola, son etiket sağa hizalı, kart dışına taşmaz), dalga, altında `Divider` ve üç sütun Başlangıç / Seçili bölüm (vurgulu) / Bitiş. (2) Yakınlaştırma `Slider`'ı (`studio.zoom`). (3) `ViewThatFits` ile yan yana / alt alta üç `ringifySecondaryAction`: Sıfırla (`studio.reset`), İşaretler · N, Öneriler. İşaretler ve Öneriler `AudioProjectMarkersPanel` ile `AudioSegmentSuggestionsPanel`'i `.medium/.large` sheet içinde `Form` olarak açar. Dalga editörü: seçili çubuklar `accent`, dışı `.tertiaryLabel`; Fotoğraflar kırpması gibi çerçeve: üst ve alt 2,5 pt `accent` kenar, iki yanda dikey `chevron` taşıyan `accent` tutamak, seçim içi `accent` %10; imleç `Color.primary` 2 pt. Tutamak isabet alanı en az 44 pt; dar seçimde (<44 pt) iki isabet alanı üst/alt yarıya ayrılır (mevcut davranış). Alt çubuk (`ringifyBottomBar`): solda `DurationText` geçen/toplam, ortada `RingifyCircleButton` oynat (prominent, 56), sağda döngü (`isSelected`) ve durdur; altında `RingifyPrimaryButton` "Efektlere Devam Et". Erişilebilirlik boyutlarında alt çubuk yerine içerik içinde (mevcut davranış). Boş durum: `ContentUnavailableView` + "Ses ekle" (ana) ve "Kütüphaneyi aç" (destek).

**İçe Aktar (`ImportSourceView`) — `List`, `.inline`.** Üç bölüm: "Dosya Seç" (Fotoğraflar'dan Video, Dosyalar'dan Ses, Dosyalar'dan Video), "Kaydet" (Mikrofonla Kaydet, ok), "Diğer" (Ses Dönüştür, ok; Kütüphane, ok). `RingifyRow` alt başlıklı. Çalışırken `.regularMaterial` üzerinde `ProgressView`.

**Dönüştür (`AudioConversionView`) — `Form`, `.inline`.** Kaynak seçimi, Çıktı bölümü, durum ve sonuç bölümleri. "Dönüştür" alt çubukta ana eylem (`conversion.start`, kaynak yokken devre dışı). Sonuçta `ShareLink` ana eylem.

**Ses Kaydı (`VoiceRecorderView`) — Ses Notları düzeni.** Üstte durum metni (kayıtta kırmızı nokta), ortada `@ScaledMetric` ile büyük ince süre, altında gerçek RMS geçmişini çizen çubuklar (ölçüm yoksa düz çizgi; `TimelineView` tarihi değişince dizi güncellenir). Dekoratif mikrofon kaldırılır. İşaretler `List` veya kart içinde. Alt çubuk: ortada kayıt düğmesi: dış halka, içte kırmızı daire (başlat) / kırmızı yuvarlak kare (bitir), solda duraklat/devam, sağda işaret ekle. Kayıt bitince dinle düğmesi ve "Bu Kaydı Kullan" ana eylemi. Metin: `recorder.idle` "Kayda başlamak için düğmeye dokun" olur.

**Efektler (`AudioEffectsView` + paneller) — `List`/`Form`, `.inline`.** İlk bölüm: Orijinal/İşlenmiş segmenti, `NativeSelectionWaveform`, dinle düğmesi. "Ses": Ses Seviyesi, Yumuşak Başlangıç, Yumuşak Bitiş (başlık + değer + `Slider`). Sonra Normalize (Pro etiketi), Pürüzsüz Döngü. Paneller (`AdvancedEffectsPanel`, `PersonalAudioPresetsPanel`, `AudioAnalysisPanel`) `Section` + `DisclosureGroup`; içerik doğrudan satır olur, `VStack` içinde sıkışmaz. "Ön İzle" alt çubukta ana eylem.

**Ön İzleme (`RingtonePreviewView`) — `List`, `.inline`.** Bölüm 1: proje adı (`.title3.bold`), dalga, süre, ortada `RingifyCircleButton` (prominent, 64). Dekoratif zil kutusu kalkar. Bölüm 2: `NativeMetadataRow`'lar. Hata satırı ve "Tekrar Dene". Araç çubuğunda "Yeniden Düzenle" (`preview.reedit`). Alt çubukta "Dışa Aktar" (`preview.export`).

**Dışa Aktar (`ExportView`) — `Form`, `.inline`.** Bölümler: dosya adı, biçim `Picker` (Pro kuralı aynı), Seçili süre. Alt çubukta "M4A Oluştur". İlerleme: bölüm içinde `ProgressView`, başlık, İptal (yıkıcı). Başarı: büyük `checkmark.circle.fill` (`success`), başlık, dosya adı; `NativeMetadataRow`'lar; "Başka Biçimde Dışa Aktar" ve "Zil Sesi Olarak Ayarla" (ok) satırları; alt çubukta paylaş (`ShareLink`).

**Rehber (`RingtoneGuideView`) — `List`, `.inline`.** Üstte segment (`guide.method`, satır zemini `Color.clear`). Adımlar tek bölümde: `\(n).circle.fill` sembolü, başlık, açıklama (ayrı kartlar ve dekoratif kutu kalkar). "Yöntem hakkında" `DisclosureGroup`. "Yardım Merkezi" (`guide.help`, ok). Alt çubukta paylaş (ana) veya Bitti.

**Kütüphane (`LibraryView` ve ilgili dosyalar) — `List`, `.insetGrouped`, `.large`.** `.searchable`. Araç çubuğunda seçenekler menüsü ve `+`. Kullanıcının kararı korunur: **sayaç, ızgara kısayolu, Favoriler, Koleksiyonlar, sıralama ve Son düzenlenenler ana listede görünür kalır, menüye gizlenmez.** Düzen: sistem kenar boşluklu segment; altında yatay kayan tek satır küçük kapsül düğmeler (`lineLimit(1)`, `fixedSize`, kırılmaz): Favoriler · N (`library.favorites.filter`), Koleksiyonlar (`library.collections`), sıralama (`library.sort`), ızgara (`library.layout`). Proje bölümü başlığı solda sıralama adı, sağda "N proje". Satır `RingifyProjectLabel` + sistem oku; "…" düğmesi kalkar, aynı eylemler `.contextMenu` ve kaydırma eylemlerinde. Izgara iki sütun `ringifyCard`. Proje detayı ve sayfalar sistem `List`/`Form`.

**Pro (`PremiumView`) — kök `ScrollView` kalmalı (UI testi `scrollViews` bekliyor), `.inline`.** Siyah hero kalkar. Üstte taç sembolü (`.tint`, kutusuz), "Ringify Pro", tek cümle. Özellikler sembol + metin satırları. Planlar dikey, tam genişlik seçilebilir satırlar: ad + yenileme solda, fiyat sağda, seçili olanda `checkmark.circle.fill` ve `accent` kenar (renk tek kanal değil). Alt çubuk: seçili plan özeti ve "Satın Al" / "Yönet". Altta Geri Yükle, Karşılaştırma, SSS, Koşullar, Gizlilik. Fiyatlar StoreKit'ten; metinler ve mantık aynı. `var showsProjectLimitNotice = false` eklenir; `true` ise üstte `premium.limit.title` bildirimi görünür. Araç çubuğu `RootView`'da.

**Ayarlar (`SettingsView`) — `List`, `.insetGrouped`, `.large`.** Yapı aynı. `SettingsNavigationRow` kutusuz sembole döner. **Yardım (`HelpAndErrorStatesView`):** Sistem listesi; kısa bağlantılar ızgara değil satır; konu satırlarında kutu yok.

## Kısıtlar

- Yalnız sunum. `AppModel`, servisler, view model'ler, `RingifyCore`, DSP, depolama, satın alma, fiyat ve Pro kuralları değişmez. Kaldırılan özellik yok.
- Tüm erişilebilirlik kimlikleri ve VoiceOver etiketleri korunur (yalnız `home.settings` ve `home.quick.library` kalkar).
- Yeni metin `model.uiText("TR", "EN")` ile; `.strings` dosyaları yalnız yukarıda adı geçen `recorder.idle` için değişir.

## Doğrulama

Windows'ta yalnız Swift parser çalışır; bu derleme değildir. Gerçek derleme, 131+ XCTest ve Simulator ekran görüntüleri manuel `native-validation` koşusu ister. Başarılı koşu ve görsel kabul olmadan **IMPLEMENTED_AND_TESTED** yazılmaz. Web önizlemesi bu pakette değişmedi; aynı dile taşınması ayrı karardır.

## Entegrasyon notları (06.11.2026)

- Tüm gruplar uygulandı: Home, Stüdyo, Efektler, Teslim (Önizleme/Dışa Aktarma/Rehber), İçe Aktarma/Kayıt/Dönüştürücü, Kütüphane, Pro, Ayarlar/Yardım.
- Mac derlemesinde doğrulanacak riskler: DisclosureGroup kökündeki `.task` modifier'larının List içinde tek kez çalışması; Kütüphane küçük kapsül düğmelerinin 44 pt dokunma alanı; dönüştürme sürerken boş alt çubuk şeridi; Stüdyo kırpma tutamaçlarının dokunma alanı.
- Erişilebilirlik: Kütüphane'de düzenle/çoğalt/koleksiyon/paylaş artık bağlam menüsünde; kaydırma eylemleri VoiceOver özel eylemi olarak kalır.
