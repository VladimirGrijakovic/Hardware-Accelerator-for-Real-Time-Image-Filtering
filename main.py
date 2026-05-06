import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import convolve2d

def uporedi_fajlove(fajl1_putanja, fajl2_putanja):
    try:
        # Otvaramo oba fajla i čitamo sadržaj
        with open(fajl1_putanja, 'r') as f1, open(fajl2_putanja, 'r') as f2:
            # .read().split() automatski čisti bele znake i pravi listu
            niz1 = f1.read().split()
            niz1 = niz1[::2]
            niz2 = f2.read().split()

        razlike = []
        # Određujemo dužinu za poređenje (do kraja kraćeg niza)
        duzina = min(len(niz1), len(niz2))

        for i in range(duzina):
            if niz1[i] != niz2[i]:
                # i + 1 jer brojimo od 1
                razlike.append((i + 1, niz1[i], niz2[i]))

        # Prikaz rezultata
        if not razlike:
            print("Nizovi u fajlovima su identični!")
        else:
            print(f"{'Pozicija':<10} | {'Fajl 1':<15} | {'Fajl 2':<15}")
            print("-" * 45)
            for pos, val1, val2 in razlike[0:200]:
                print(f"{pos:<10} | {val1:<15} | {val2:<15}")

        # Provera da li su fajlovi uopšte iste dužine
        if len(niz1) != len(niz2):
            print(f"\nUpozorenje: Fajlovi nemaju isti broj elemenata!")
            print(f"Fajl 1 ima {len(niz1)}, a Fajl 2 ima {len(niz2)} elemenata.")

    except FileNotFoundError as e:
        print(f"Greška: Nije moguće pronaći fajl - {e.filename}")

def binarni_u_niz(input_fajl, output_fajl):
    try:
        # Čitamo fajl kao bajtove ('rb')
        with open(input_fajl, 'rb') as f:
            bajtovi = f.read()

        # Pretvaramo svaki bajt u broj i spajamo ih razmakom
        niz_brojeva = [str(bajt) for bajt in bajtovi]

        # Upisujemo u tekstualni fajl
        with open(output_fajl, 'w') as f_out:
            f_out.write(" ".join(niz_brojeva))

        print(f"Uspešno! Brojevi su sačuvani u: {output_fajl}")
        print(f"Ukupno elemenata: {len(niz_brojeva)}")

    except FileNotFoundError:
        print("Greška: Binarni fajl nije pronađen.")

def prebroj_brojeve(putanja_fajla):
    try:
        with open(putanja_fajla, 'r') as f:
            # .read().split() razdvaja sve što je odvojeno razmakom ili novim redom
            sadrzaj = f.read().split()
            broj_elemenata = len(sadrzaj)

            print(f"Fajl: {putanja_fajla}")
            print(f"Ukupan broj brojeva u nizu: {broj_elemenata}")

            # Provera standardnih dimenzija slika
            if broj_elemenata == 262144:
                print("Ovo odgovara slici dimenzija 512x512.")
            elif broj_elemenata == 16384:
                print("Ovo odgovara slici dimenzija 128x128.")
            else:
                import math
                koren = math.sqrt(broj_elemenata)
                if koren.is_integer():
                    print(f"Ovo odgovara kvadratnoj slici dimenzija {int(koren)}x{int(koren)}.")

    except FileNotFoundError:
        print(f"Greška: Fajl '{putanja_fajla}' nije pronađen.")


def ocisti_fajl_u_mestu(ime_fajla):
    # 1. Otvaramo fajl, preskačemo 8 bajtova i učitavamo ostatak u RAM
    with open(ime_fajla, 'rb') as f:
        f.seek(8)
        podaci = f.read()

    # 2. Ponovo otvaramo ISTI fajl u 'wb' modu (ovo će ga isprazniti)
    # i upisujemo pročišćene podatke nazad
    with open(ime_fajla, 'wb') as f:
        f.write(podaci)

    print(f"Fajl '{ime_fajla}' je uspešno prepisan (obrisano prvih 8 bajtova).")

def prikazi_rezultat_mod1_txt(txt_putanja, w_out, h_out, shift_bits=7):
    """
    Prikazuje sliku iz TXT fajla (lista bajtova) za Mod 1.
    Spaja po dva bajta u jedan 16-bitni signed broj i deli sa 2^shift_bits.
    """
    try:
        # 1. Učitavanje pojedinačnih bajtova iz TXT fajla
        with open(txt_putanja, 'r') as f:
            data = f.read().split()
            all_bytes = [int(p) for p in data]

        # 2. Spajanje bajtova u 16-bitne brojeve
        # Pretpostavljamo Little-Endian (prvi bajt je niži, drugi viši)
        # Ako slika izgleda kao nasumičan šum, zameni b1 i b2 mesta u formuli
        pixels_16bit = []
        for i in range(0, len(all_bytes) - 1, 2):
            b1 = all_bytes[i]  # Niži bajt
            b2 = all_bytes[i + 1]  # Viši bajt

            # Formiranje 16-bitne vrednosti
            val = b1 + (b2 << 8)

            # Pretvaranje u signed (označen) broj ako je vrednost > 32767
            if val > 32767:
                val -= 65536

            pixels_16bit.append(val)

        # 3. Skaliranje fiksnog zareza (deljenje sa 2^7 = 128)
        pixels = [p / (2 ** shift_bits) for p in pixels_16bit]

        print(f"Ukupno bajtova: {len(all_bytes)}")
        print(f"Broj spojenih 16-bitnih piksela: {len(pixels)}")

        # 4. Formiranje matrice i prikaz
        expected_size = w_out * h_out
        if len(pixels) < expected_size:
            print(f"Upozorenje: Nedovoljno piksela! Ima {len(pixels)}, treba {expected_size}")
            # Prilagođavanje visine onome što imamo
            h_out = len(pixels) // w_out

        img_array = np.array(pixels[:w_out * h_out]).reshape((h_out, w_out))

        # 5. Vizuelizacija
        plt.figure(figsize=(10, 8))
        # Koristimo vmin=0, vmax=255 da skala bude ista kao na originalu
        img_plot = plt.imshow(img_array, cmap='gray', vmin=0, vmax=255)
        plt.title(f"Rezultat Mod 1 (TXT: {txt_putanja})\nFiksni zarez (skalirano sa 1/{2 ** shift_bits})")
        plt.colorbar(img_plot, label="Intenzitet")
        plt.show()

        return img_array

    except Exception as e:
        print(f"Greška pri obradi Moda 1: {e}")
def prikazi_rezultat_mod0_txt(txt_putanja, w_out, h_out):
    """
    Prikazuje sliku iz TXT fajla koji je nastao od binarnog fajla (bajt po bajt).
    Koristi logiku uzimanja svakog drugog elementa (pixels[::2]).
    """
    try:
        # 1. Učitavanje brojeva iz tekstualnog fajla
        with open(txt_putanja, 'r') as f:
            data = f.read().split()
            # Pretvaramo u integer listu (svaki broj je jedan bajt iz originalnog fajla)
            all_bytes = [int(p) for p in data]

        # 2. Uzimanje svakog drugog bajta (tvoj ključni korak)
        # Ovo radi jer VHDL šalje 16 bita kao [podatak, 00] ili [00, podatak]
        pixels = all_bytes[::2]

        print(f"Ukupno bajtova u fajlu: {len(all_bytes)}")
        print(f"Broj piksela nakon filtriranja [::2]: {len(pixels)}")

        # 3. Formiranje matrice
        expected_size = w_out * h_out
        if len(pixels) != expected_size:
            print(f"Upozorenje: Broj piksela ({len(pixels)}) se ne slaže sa {w_out}x{h_out}!")
            # Automatsko određivanje stranice ako dimenzije nisu tačne
            side = int(len(pixels) ** 0.5)
            img_array = np.array(pixels[:side * side]).reshape((side, side))
        else:
            img_array = np.array(pixels).reshape((h_out, w_out))

        # 4. Prikaz
        plt.figure(figsize=(8, 8))
        plt.imshow(img_array, cmap='gray', vmin=0, vmax=255)
        plt.title(f"Rezultat Mod 0 (TXT: {txt_putanja})")
        plt.colorbar(label="Intenzitet (0-255)")
        plt.show()

        return img_array

    except Exception as e:
        print(f"Greška pri prikazu: {e}")


binarni_u_niz('lena_128.bin', 'lena_128.txt')
binarni_u_niz('lena_512.bin', 'lena_512.txt')

prebroj_brojeve('lena_128.txt')
prebroj_brojeve('lena_512.txt')

"""
# 1. Učitavanje lena_128.bin (pretpostavka: 128x128, 8-bit unsigned)
side = 128
try:
    with open("lena_128.bin", "rb") as f:
        img_data = np.frombuffer(f.read(), dtype=np.uint8)
        #img = img_data[8:].reshape((side, side))
        img = img_data.reshape((side, side))
except FileNotFoundError:
    print("Greška: Fajl lena_512.bin nije pronađen u trenutnom folderu.")
    exit()

# 2. Definisanje Box Filter kernela (3x3 usrednjavanje)
# Svaki koeficijent je 1/9
kernel = np.ones((3, 3)) / 9.0

# 3. Primena filtriranja
# Koristimo mode='valid' jer tvoj akcelerator ne obrađuje ivice (seče ih)
# Rezultat će biti 126x126 (128 - 3 + 1)
img_filtered = convolve2d(img, kernel, mode='valid')

# 4. Prikaz originala i filtrirane slike
plt.figure(figsize=(12, 6))

plt.subplot(1, 2, 1)
plt.imshow(img, cmap='gray')
plt.title(f"Originalna Lena ({side}x{side})")
plt.axis('off')

plt.subplot(1, 2, 2)
plt.imshow(img_filtered, cmap='gray')
plt.title(f"Box Filter 3x3 (Valid area: {img_filtered.shape[0]}x{img_filtered.shape[1]})")
plt.axis('off')

plt.tight_layout()
plt.show()

# Opciono: Sačuvaj rezultat u tekstualni fajl ako želiš da porediš sa Vivadom
np.savetxt("box_filter_ref.txt", img_filtered, fmt='%d')
"""


binarni_u_niz('lena128filtHWrez1.bin', 'lena128filtHWrez1.txt')
binarni_u_niz('lena512LoGfiltHW0.bin', 'lena512LoGfiltHW0.txt')
binarni_u_niz('lena128GaussHW0.bin', 'lena128GaussHW0.txt')
binarni_u_niz('lena128SharpGaussHW0.bin', 'lena128SharpGaussHW0.txt')
binarni_u_niz('lena512SharpBoxHW0.bin', 'lena512SharpBoxHW0.txt')

prikazi_rezultat_mod0_txt('lena128filtHWrez1.txt', 126,126)
prikazi_rezultat_mod1_txt('lena512LoGfiltHW0.txt', 506, 506)
prikazi_rezultat_mod1_txt('lena128GaussHW0.txt', 124, 124)
prikazi_rezultat_mod0_txt('lena512SharpBoxHW0.txt', 504, 504)
prikazi_rezultat_mod0_txt('lena128SharpGaussHW0.txt', 124, 124)