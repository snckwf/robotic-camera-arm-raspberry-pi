// box_elettronica.scad — Scatola chiusa per l'elettronica del braccio telecamera
// v3 (19/10/2026): scatola piu' grande. Dentro: alimentatore 5V 5A (85x58x32), breakout Freenove FNK0080 (fori 58x49),
//         PCA9685 (servi), traslatore di livello BSS138 (LCD), modulo ULN2003, 4 morsetti Forbox per 5V/GND,
//         interruttore 230V e ingresso rete.
// La breakout e' collegata al Pi sul coperchio con un cavo GPIO a 40 poli che passa dalla feritoia del coperchio.
// Sopra il coperchio, all'aperto: Raspberry Pi 4 nella custodia GeeekPi Armor (87x56x25).
// Coperchio chiuso con 4 viti M3 a testa tonda avvitate nelle colonnine (fori pilota 2,5).
// Display LCD 16x2: scatolina separata in due pezzi (display_guscio + display_fondo) da fissare dove si vuole.
// Breakout su colonnine con viti M2,5 del kit, ULN2003 con autofilettanti M2. L'alimentatore si fissa con le sue viti (fondo piatto).
// Tutte le misure in mm. Modificare solo i parametri qui sotto.

/* [Parte da generare] */
parte = "assieme"; // [assieme, scatola, coperchio, fermacavo, display_guscio, display_fondo]

/* [Scatola] */
in_x      = 190;   // interno lungo X
in_y      = 132;   // interno lungo Y
in_h      = 50;    // interno: dal fondo al coperchio
parete    = 2.4;   // 2,4 mm: adatto alle alette a scatto degli interruttori a bilanciere (pannello 1-3 mm)
fondo     = 3;
coperchio_h = 3;
colonna   = 10;    // colonnine d'angolo per le viti del coperchio (quadrate)
pilota_m3 = 2.5;   // vite M3 avvitata nella plastica
passante_m3 = 3.4;
testa_m3  = 6.5;   // lamatura testa tonda M3 (ISO 7380)

/* [Alimentatore 5V 5A] */
psu_x     = 85;    // lunghezza (morsettiera sul lato corto verso +X)
psu_y     = 58;
psu_h     = 32;
psu_pos   = [12, 6];

/* [Breakout Freenove e ULN2003] */
bo_x = 85; bo_y = 56;            // ingombro scheda (formato Raspberry Pi)
bo_pos = [11, 72];               // angolo della scheda
bo_fori = [[3.5, 3.5], [61.5, 3.5], [3.5, 52.5], [61.5, 52.5]];   // fori M2,5 (schema Pi/HAT 58 x 49)
bo_alt  = 11;                    // altezza colonnine: lasciano spazio al connettore 40 poli sotto la scheda
col_d   = 12;                    // diametro colonnine
col_base = 18;                   // diametro del raccordo conico alla base (rinforzo contro lo strappo)
col_base_h = 5;                  // altezza del raccordo
bo_taglio = 2.6;                 // colonnine tagliate a 2,6 mm dal centro foro verso il centro scheda (connettore 40 poli sotto)
passante_m25 = 2.8;              // foro per vite M2,5
dado_m25  = 5.4;                 // chiave dado M2,5 (5) + gioco
dado_m25_h = 2.3;                // altezza sede dado (dado 2)
dado_m25_z = 0.6;                // spessore sopra il dado: la vite M2,5x4 del kit (4 - 1,6 di scheda) prende tutto il dado
uln_x = 35; uln_y = 32; uln_sp = 1.6; uln_aria = 4; uln_pos = [144, 86];
wago_anc = [[108, 14], [128, 14], [108, 34], [128, 34]]; // ancoraggi per fascette dei 4 morsetti Forbox (2 per +5V, 2 per GND)
pca_pos  = [118, 52];            // PCA9685 (servi): angolo della scheda
pca_dim  = [62.3, 25.4];
pca_fori = [[3.2, 3.15], [59.1, 3.15], [3.2, 22.25], [59.1, 22.25]];   // fori M2,5 (interasse 55,9 x 19,1: misurare)
pca_alt  = 6;                    // colonnine (vite M2,5x8 autofilettante nel foro pilota)
pilota_m25 = 2.1;
bss_pos  = [97, 54];            // angolo interno dell'alloggiamento            // traslatore di livello BSS138 4 canali (si ferma con una goccia di colla a caldo)
bss_dim  = [16.4, 15.9];        // vano: modulo 16 x 15,5 (6 pin a passo 2,54 per fila, file a 12,7 mm) + 0,2 per lato; pin verso l'alto
bss_par  = 2;                   // pareti dell'alloggiamento
bss_h    = 4.5;                 // pareti alte sui lati senza pin (con dentini a scatto)
bss_h_pin = 2.2;                // pareti basse sui lati delle file di pin (non ostacolano i Dupont)
uln_foro = [2.5, 2.5];   // fori d'angolo ULN2003: misurare col calibro
gioco_pcb = 0.4;
parete_ang = 1.8;
braccio_ang = 8;
pilota_m2 = 1.6;

/* [Interruttore 230V e ingresso rete (parete frontale Y=0)] */
sw_x      = 158;   // centro interruttore lungo X
sw_w      = 19.2;  // foro interruttore a bilanciere KCD1 (19,2 x 12,9); KCD3 grande: 28 x 22
sw_h      = 12.9;
sw_z      = 26;    // centro foro sopra il fondo
rete_x    = 178;   // centro foro cavo di rete
rete_d    = 8;     // cavo 3x0,75 (d 6-7); per pressacavo PG7 mettere 12.5
rete_z    = 6;     // centro foro sopra il fondo (il cavo appoggia sul fondo)
fc_int    = 18;    // interasse viti del fermacavo
fc_alt    = 5;     // altezza colonnine fermacavo (schiaccia il cavo d 7 a 5 mm)
fc_y      = 16;    // distanza del fermacavo dalla parete frontale

/* [Uscita cavi verso il braccio (parete destra X=in_x)] */
usc_y     = [58, 116];
usc_z     = [10, 32];

/* [Raspberry Pi sul coperchio] */
pi_x = 87; pi_y = 56; pi_gioco = 1.5;
pi_pos    = [10, 44];   // angolo della culla (interno) sul coperchio
pi_par    = 2.4;
pi_bra    = 14;
pi_h      = 10;
dup_slot  = [[14, 114], [66, 13]];  // feritoia per il cavo GPIO 40 poli: passa il connettore IDC (56 x 9 + chiavetta) con margine
usbc_slot = [[14, 32], [16, 9]];    // passaggio cavo USB-C di alimentazione del Pi
cinghia   = [12, 3];

/* [Scatolina display LCD 16x2 a 45 gradi (separata: si fissa dove si vuole)] */
tl_sul_coperchio = false;   // true = vecchia versione integrata nel coperchio (mensola + apertura)
df_sp      = 4;         // spessore fondo della scatolina
df_orecchia = 12;       // aletta sul lato sinistro del fondo con 2 fori per fissarla (viti M3); a destra niente aletta
df_cavo    = 8;         // foro passaggio cavo nel fondo
lcd_pcb    = [80, 36];  // scheda LCD 1602
lcd_fori   = [75, 31];  // interasse fori di fissaggio della scheda (misurare)
lcd_fin    = [72, 25];  // finestra per la cornice metallica (cornice 71 x 24-26)
lcd_corn   = 7;         // altezza cornice metallica sopra la scheda (misurare): la cornice arriva a filo del frontale
lcd_gioco  = [13, 6];   // spazio tra scheda e pareti: sinistra (uscita pin I2C del modulo) / destra
tl_xf      = in_x + parete;   // x del frontale della torretta: a filo del lato destro della scatola
tl_fuori   = 0.6;       // parte della torretta fuori dalla sagoma della scatola (0,6 = 60%)
tl_par     = 2.4;       // spessore pareti
tl_marg    = [10, 3];    // margine sotto / sopra la scheda lungo il piano inclinato
tl_prof    = 48;        // profondita' totale (spazio dietro la scheda per il modulo I2C saldato sopra)
tl_bor_d   = 8;         // borchie delle 4 viti M3 di fissaggio (avvitate da sotto il coperchio)
tl_bor_h   = 8;
tl_bor_xy  = [4, 8.4];  // distanza borchie dai bordi (x) e dal fronte (y)
lcd_bor_d  = 5.5;       // borchie viti della scheda LCD (M3 x 6 nel foro pilota)

/* [Fissaggio al ripiano] */
orecchia  = 10;
vite_legno = 4.5;
vite_testa = 8.5;

/* [Qualita'] */
$fn = 40;

// ---------------------------------------------------------------- quote derivate
ex = in_x + 2 * parete;
ey = in_y + 2 * parete;
ez = fondo + in_h;                 // altezza scatola (bordo superiore)
est = gioco_pcb + parete_ang;
pest = pi_gioco + pi_par;
tl_L  = lcd_pcb[0] + lcd_gioco[0] + lcd_gioco[1] + 2 * tl_par;   // lunghezza torretta
tl_lx = tl_par + lcd_gioco[0] + lcd_pcb[0] / 2;                  // centro scheda lungo x
tl_s  = (tl_marg[0] + lcd_pcb[1] + tl_marg[1]) / sqrt(2);  // altezza (piano inclinato a 45 gradi)
tl_lc = tl_marg[0] + lcd_pcb[1] / 2;                  // centro scheda lungo il piano inclinato
function tl_viti() = [[tl_bor_xy[0], tl_bor_xy[1]], [tl_L - tl_bor_xy[0], tl_bor_xy[1]],
                      [tl_bor_xy[0], tl_prof - tl_par - 4], [tl_L - tl_bor_xy[0], tl_prof - tl_par - 4]];
tl_y0 = in_y + parete - (1 - tl_fuori) * tl_L;      // y dell'estremo interno della torretta (l'altro sporge oltre il lato posteriore)
tl_ap = [[11, 14], [in_y - 2 - tl_y0, tl_prof - tl_par - 9]];   // apertura nel coperchio sotto la torretta (solo dentro la scatola)
module tl_su_coperchio() translate([tl_xf, tl_y0, 0]) rotate(90) children();   // sistema torretta -> coperchio (schermo verso X+)
// la torretta copre l'angolo posteriore destro: li' il coperchio non ha la vite (resta fissato con le altre 3)
function viti_coperchio() = [for (c = colonne()) if (!tl_sul_coperchio || !(c[0] > in_x / 2 && c[1] > in_y / 2)) c];
// le coordinate interne partono da (0,0, fondo): la scatola e' traslata di -parete
echo(str("Scatola esterna: ", ex, " x ", ey, " x ", ez, " mm; con coperchio ", ez + coperchio_h));
echo(str("Breakout ", bo_x, " x ", bo_y, " su colonnine h ", bo_alt, ", ULN ", uln_x + 2 * gioco_pcb, " x ", uln_y + 2 * gioco_pcb));

// asola verticale passante in una parete parallela a YZ (lungo X) o XZ (lungo Y): estremita' semicircolari
module asola_x(x0, y, z0, z1, w) hull() for (z = [z0, z1]) translate([x0, y, z]) rotate([0, 90, 0]) cylinder(d = w, h = parete + 2, $fn = 24);
module asola_y(x, y0, z0, z1, w) hull() for (z = [z0, z1]) translate([x, y0, z]) rotate([-90, 0, 0]) cylinder(d = w, h = parete + 2, $fn = 24);

function colonne() = [[colonna / 2, colonna / 2], [in_x - colonna / 2, colonna / 2],
                      [colonna / 2, in_y - colonna / 2], [in_x - colonna / 2, in_y - colonna / 2]];

module arrotondato(x, y, h, r = 3) {
    hull() for (i = [r, x - r], j = [r, y - r]) translate([i, j, 0]) cylinder(r = r, h = h);
}

// ---------------------------------------------------------------- angolari PCB con foro M2 (come supporto_pcb v3)
module angolare(z_app, sp, fx, fy) {
    z_top = z_app + sp + 1.5;
    ax = fx + 2.4; ay = fy + 2.4;
    difference() {
        translate([-gioco_pcb, -gioco_pcb, 0]) cube([ax + gioco_pcb, ay + gioco_pcb, z_app]);
        translate([fx, fy, z_app - 6]) cylinder(d = pilota_m2, h = 6.01, $fn = 20);
    }
    translate([-est, -est, 0]) cube([parete_ang, braccio_ang + est, z_top]);
    translate([-est, -est, 0]) cube([braccio_ang + est, parete_ang, z_top]);
}
module quattro_angolari(pos, lx, ly, z_app, sp, f) {
    translate([pos[0], pos[1], 0]) {
        angolare(z_app, sp, f[0], f[1]);
        translate([lx, 0, 0])  mirror([1, 0, 0]) angolare(z_app, sp, f[0], f[1]);
        translate([0, ly, 0])  mirror([0, 1, 0]) angolare(z_app, sp, f[0], f[1]);
        translate([lx, ly, 0]) mirror([1, 0, 0]) mirror([0, 1, 0]) angolare(z_app, sp, f[0], f[1]);
    }
}

// ---------------------------------------------------------------- scatola (sistema: interno da (0,0), fondo interno a z = fondo)
module scatola() {
    difference() {
        union() {
            translate([-parete, -parete, 0]) arrotondato(ex, ey, ez);
            // orecchie per le viti da legno (lati X)
            for (x = [-parete - orecchia, in_x + parete - 3], y = [12, in_y - 12 - 16])
                translate([x, y, 0]) cube([orecchia + 3, 16, 4]);
        }
        // vano interno
        translate([0, 0, fondo]) cube([in_x, in_y, in_h + 1]);
        // fori viti da legno svasati
        for (x = [-parete - orecchia / 2, in_x + parete + orecchia / 2], y = [20, in_y - 20])
            translate([x, y, -0.01]) {
                cylinder(d = vite_legno, h = 5);
                translate([0, 0, 4 - (vite_testa - vite_legno) / 2 + 0.02]) cylinder(d1 = vite_legno, d2 = vite_testa, h = (vite_testa - vite_legno) / 2);
            }
        // parete frontale: interruttore e ingresso rete
        translate([sw_x - sw_w / 2, -parete - 1, fondo + sw_z - sw_h / 2]) cube([sw_w, parete + 2, sw_h]);
        translate([rete_x, 1, fondo + rete_z]) rotate([90, 0, 0]) cylinder(d = rete_d, h = parete + 2);
        // parete destra: uscita cavi verso il braccio (asola con raggi)
        translate([in_x - 1, 0, fondo]) hull() for (y = usc_y, z = usc_z)
            translate([0, y, z]) rotate([0, 90, 0]) cylinder(r = 4, h = parete + 2);
        // parete sinistra: aerazione accanto all'alimentatore (asole verticali a estremita' tonde: niente supporti)
        for (i = [0:6]) asola_x(-parete - 1, psu_pos[1] + 7.5 + i * 7, fondo + 9.5, fondo + psu_h - 3.5, 3);
        // parete posteriore: aerazione alta (asole verticali)
        for (i = [0 : floor((in_x - 34) / 12)]) asola_y(22 + i * 12, in_y - 1, fondo + in_h - 12, fondo + in_h - 6, 4);
    }
    // colonnine d'angolo per le viti del coperchio
    for (c = colonne()) difference() {
        translate([c[0] - colonna / 2, c[1] - colonna / 2, 0]) cube([colonna, colonna, ez]);
        translate([c[0], c[1], ez - 14]) cylinder(d = pilota_m3, h = 14.1);
    }
    // supporti millefori e ULN2003
    translate([0, 0, fondo - 0.01]) {
        // colonnine della breakout Freenove: vite M2,5x4 del kit dall'alto in un dado M2,5 infilato di lato vicino alla cima
        for (f = bo_fori) translate([bo_pos[0] + f[0], bo_pos[1] + f[1], 0]) difference() {
            // colonnina con raccordo conico alla base; tagliata dove tocca l'alimentatore (y < 62,4)
            intersection() {
                union() {
                    cylinder(d = col_d, h = bo_alt);
                    cylinder(d1 = col_base, d2 = col_d, h = col_base_h);
                }
                translate([-20, psu_pos[1] + psu_y + 0.4 - (bo_pos[1] + f[1]), -1]) cube([40, in_y - (psu_pos[1] + psu_y + 0.4), bo_alt + 2]);   // dentro la scatola
            }
            translate([0, 0, bo_alt - 8]) cylinder(d = passante_m25, h = 8.1);
            // lato verso il centro tagliato: lascia libero il connettore femmina 40 poli sotto la scheda
            // (sta tra i fori, sulla stessa fila, da 3,6 mm dal centro foro in poi)
            translate([f[0] < 30 ? bo_taglio : -bo_taglio - 30, -20, -1]) cube([30, 40, bo_alt + 2]);
            // sede dado aperta verso l'esterno della scheda: si infila il dado prima di montare la breakout
            translate([0, 0, bo_alt - dado_m25_z - dado_m25_h]) hull() {
                rotate(30) cylinder(d = dado_m25 / cos(30), h = dado_m25_h, $fn = 6);
                translate([(f[0] < 30 ? -1 : 1) * 8, 0, 0]) rotate(30) cylinder(d = dado_m25 / cos(30), h = dado_m25_h, $fn = 6);
            }
        }
        // ancoraggi per fascetta dei morsetti Forbox (ponticello sul fondo)
        for (w = wago_anc) translate([w[0] - 3, w[1] - 5, 0]) difference() {
            cube([6, 10, 5]);
            translate([-1, 3.4, -0.01]) cube([8, 3.2, 2.6]);
        }
        quattro_angolari(uln_pos, uln_x, uln_y, uln_aria, uln_sp, uln_foro);
        // colonnine della PCA9685 (con raccordo alla base)
        for (q = pca_fori) translate([pca_pos[0] + q[0], pca_pos[1] + q[1], 0]) difference() {
            union() { cylinder(d = 6.5, h = pca_alt); cylinder(d1 = 10, d2 = 6.5, h = 2.5); }
            translate([0, 0, 0.8]) cylinder(d = pilota_m25, h = pca_alt, $fn = 20);
        }
        // alloggiamento del traslatore BSS138: vasca con pareti basse sui lati dei pin e dentini a scatto sugli altri due
        translate([bss_pos[0], bss_pos[1], 0]) {
            difference() {
                translate([-bss_par, -bss_par, 0]) cube([bss_dim[0] + 2 * bss_par, bss_dim[1] + 2 * bss_par, bss_h]);
                translate([0, 0, -1]) cube([bss_dim[0], bss_dim[1], bss_h + 2]);
                // lati con le file di pin (lungo X): pareti abbassate
                for (y = [-bss_par - 1, bss_dim[1] - 0.01]) translate([-bss_par - 1, y, bss_h_pin]) cube([bss_dim[0] + 2 * bss_par + 2, bss_par + 1.01, bss_h]);
                // finestra sotto il centro: si spinge fuori il modulo con un cacciavite dal fondo
            }
            // dentini a scatto (lati senza pin, lungo Y): appena sopra la scheda (1,6) con invito
            for (s = [0, 1]) translate([s * bss_dim[0], bss_dim[1] / 2 - 3, 1.8]) mirror([s, 0, 0])
                hull() { cube([0.01, 6, 1.2]); translate([0, 0, 0]) cube([0.6, 6, 0.4]); }
        }
    }
    // colonnine del fermacavo di rete
    for (s = [-1, 1]) translate([rete_x + s * fc_int / 2, fc_y, fondo - 0.01]) difference() {
        cylinder(d = 8, h = fc_alt);
        cylinder(d = pilota_m3, h = fc_alt + 1);
    }
}

// ---------------------------------------------------------------- coperchio (stesso sistema, appoggia a z = ez)
module coperchio() {
    translate([0, 0, ez]) {
        difference() {
            union() {
                translate([-parete, -parete, 0]) arrotondato(ex, ey, coperchio_h);
                // mensola a sbalzo sotto la torretta LCD (solo versione integrata)
                if (tl_sul_coperchio) translate([tl_xf - tl_prof, tl_y0, 0]) arrotondato(tl_prof, tl_L, coperchio_h, 3);
            }
            // viti M3 nelle colonnine con lamatura per la testa tonda
            for (c = viti_coperchio()) translate([c[0], c[1], -1]) {
                cylinder(d = passante_m3, h = coperchio_h + 2);
                translate([0, 0, 1 + coperchio_h - 1.8]) cylinder(d = testa_m3, h = 3);
            }
            // feritoia cavi Dupont (sopra il pettine della millefori) e passaggio USB-C del Pi
            for (s = [dup_slot, usbc_slot]) translate([s[0][0], s[0][1], -1]) arrotondato(s[1][0], s[1][1], coperchio_h + 2, 2);
            // aerazione sopra l'alimentatore
            for (i = [0:7]) translate([40 + i * 7, 8, -1]) arrotondato(3, 26, coperchio_h + 2, 1.4);
            // aerazione sopra PCA9685 e ULN2003
            for (i = [0:8]) translate([116 + i * 8, 54, -1]) arrotondato(3, 26, coperchio_h + 2, 1.4);
            // passacavo per i fili del display (I2C) e altri cavi esterni
            translate([170, 112, -1]) cylinder(d = 12, h = coperchio_h + 2);
            // torretta LCD: apertura per cavi e aria + 4 fori M3 (viti da sotto, nelle borchie della torretta)
            if (tl_sul_coperchio) tl_su_coperchio() {
                translate([tl_ap[0][0], tl_ap[0][1], -1]) arrotondato(tl_ap[1][0] - tl_ap[0][0], tl_ap[1][1] - tl_ap[0][1], coperchio_h + 2, 3);
                for (v = tl_viti()) translate([v[0], v[1], -1]) cylinder(d = passante_m3, h = coperchio_h + 2);
            }
            // asole cinghie velcro per la custodia del Pi
            for (x = [pi_pos[0] + 30, pi_pos[0] + pi_x + 2 * pi_gioco - 30], y = [pi_pos[1] - 1 - cinghia[1], pi_pos[1] + pi_y + 2 * pi_gioco + 1])
                translate([x - cinghia[0] / 2, y, -1]) cube([cinghia[0], cinghia[1], coperchio_h + 2]);
        }
        // culla della custodia Pi: 4 angolari bassi, porte libere
        translate([pi_pos[0] + pi_gioco, pi_pos[1] + pi_gioco, coperchio_h - 0.01]) {
            for (m = [[0, 0], [1, 0], [0, 1], [1, 1]])
                translate([m[0] * pi_x, m[1] * pi_y, 0]) mirror([m[0], 0, 0]) mirror([0, m[1], 0]) {
                    translate([-pest, -pest, 0]) cube([pi_par, pi_bra + pest, pi_h]);
                    translate([-pest, -pest, 0]) cube([pi_bra + pest, pi_par, pi_h]);
                }
        }
    }
}

// ---------------------------------------------------------------- torretta LCD 16x2 a 45 gradi
// sistema locale: x lungo la torretta, y verso il retro (y=0 fronte), z in alto (z=0 appoggio sul coperchio)
module tl_profilo() polygon([[0, 0], [tl_s, tl_s], [tl_prof, tl_s], [tl_prof, 0]]);
module tl_su_piano(d, x) translate([x, d / sqrt(2), d / sqrt(2)]) rotate([45, 0, 0]) children();  // z locale = normale uscente
module torretta_lcd() {
    difference() {
        union() {
            difference() {
                rotate([90, 0, 90]) linear_extrude(tl_L) tl_profilo();
                // vano interno, aperto sotto
                translate([tl_par, 0, 0]) rotate([90, 0, 90]) linear_extrude(tl_L - 2 * tl_par) {
                    offset(delta = -tl_par) tl_profilo();
                    translate([tl_par * (1 + sqrt(2)), -1]) square([tl_prof - tl_par - tl_par * (1 + sqrt(2)), tl_par + 1.01]);
                }
            }
            // borchie delle viti di fissaggio al coperchio
            intersection() {
                for (v = tl_viti()) translate([v[0], v[1], 0]) cylinder(d = tl_bor_d, h = tl_bor_h);
                rotate([90, 0, 90]) linear_extrude(tl_L) tl_profilo();
            }
            // borchie della scheda LCD (dietro il piano inclinato)
            for (i = [-1, 1], j = [-1, 1]) tl_su_piano(tl_lc + j * lcd_fori[1] / 2, tl_lx + i * lcd_fori[0] / 2)
                translate([0, 0, -lcd_corn]) cylinder(d = lcd_bor_d, h = lcd_corn - 0.5);
        }
        // finestra per la cornice del display
        tl_su_piano(tl_lc, tl_lx) translate([-lcd_fin[0] / 2, -lcd_fin[1] / 2, -tl_par - 1]) cube([lcd_fin[0], lcd_fin[1], tl_par + 2]);
        // fori pilota viti LCD (M3: non passanti, resta 1 mm)
        for (i = [-1, 1], j = [-1, 1]) tl_su_piano(tl_lc + j * lcd_fori[1] / 2, tl_lx + i * lcd_fori[0] / 2)
            translate([0, 0, -lcd_corn - 1]) cylinder(d = pilota_m3, h = lcd_corn);
        // fori pilota viti di fissaggio (da sotto)
        for (v = tl_viti()) translate([v[0], v[1], -1]) cylinder(d = pilota_m3, h = 7);
        // aerazione sul retro (asole verticali)
        for (i = [0:6]) hull() for (z = [7, tl_s - 7]) translate([tl_L / 2 + (i - 3) * 9, tl_prof + 1, z]) rotate([90, 0, 0]) cylinder(d = 3, h = tl_par + 2, $fn = 20);
    }
}
// fondo della scatolina display: chiude sotto, 4 viti M3 da sotto nelle borchie del guscio, alette per fissarla
module display_fondo() {
    gi = 0.3;   // gioco del bordino di centraggio dentro le pareti del guscio
    difference() {
        union() {
            translate([-df_orecchia, 0, 0]) arrotondato(tl_L + df_orecchia, tl_prof, df_sp, 3);
            // bordino di centraggio dentro il guscio
            translate([0, 0, df_sp - 0.01]) difference() {
                translate([tl_par + gi, tl_par * (1 + sqrt(2)) + gi + 1.5, 0]) cube([tl_L - 2 * (tl_par + gi), tl_prof - tl_par * (2 + sqrt(2)) - 2 * gi - 1.5, 1.5]);
                translate([tl_par + gi + 1.6, tl_par * (1 + sqrt(2)) + gi + 3.1, -1]) cube([tl_L - 2 * (tl_par + gi + 1.6), tl_prof - tl_par * (2 + sqrt(2)) - 2 * gi - 4.7, 4]);
                for (v = tl_viti()) translate([v[0], v[1], -1]) cylinder(d = tl_bor_d + 0.8, h = 4);
            }
        }
        // viti del guscio (testa incassata sotto)
        for (v = tl_viti()) translate([v[0], v[1], -1]) {
            cylinder(d = passante_m3, h = df_sp + 3);
            cylinder(d = testa_m3, h = 1 + 2);
        }
        // fori di fissaggio nelle alette
        for (x = [-df_orecchia / 2], y = [tl_prof / 2 - 12, tl_prof / 2 + 12])
            translate([x, y, -1]) cylinder(d = passante_m3, h = df_sp + 2);
        // passaggio cavo (vicino all'uscita dei pin I2C del modulo, lato sinistro)
        translate([tl_par + lcd_gioco[0], tl_prof - 16, -1]) cylinder(d = df_cavo, h = df_sp + 4);
    }
}

module lcd_sagoma() {   // scheda + cornice + modulo I2C saldato dietro (solo anteprima)
    tl_su_piano(tl_lc, tl_lx) {
        translate([-lcd_pcb[0] / 2, -lcd_pcb[1] / 2, -lcd_corn - 1.6]) cube([lcd_pcb[0], lcd_pcb[1], 1.6]);
        translate([-71 / 2, -24 / 2, -lcd_corn]) cube([71, 24, lcd_corn]);
        translate([-lcd_pcb[0] / 2 + 2, lcd_pcb[1] / 2 - 21, -lcd_corn - 1.6 - 10]) cube([42, 19, 10]);
        translate([-lcd_pcb[0] / 2 - 12, lcd_pcb[1] / 2 - 15, -lcd_corn - 1.6 - 8]) cube([14, 10, 3]);   // pin I2C verso sinistra
    }
}

// ---------------------------------------------------------------- fermacavo di rete
module fermacavo() {
    difference() {
        hull() for (s = [-1, 1]) translate([s * fc_int / 2, 0, 0]) cylinder(d = 9, h = 3);
        for (s = [-1, 1]) translate([s * fc_int / 2, 0, -1]) cylinder(d = passante_m3, h = 5);
    }
}

// ---------------------------------------------------------------- assieme con sagome
module assieme() {
    color("#f39c12") scatola();
    color("#e8590c") coperchio();
    color("#e8590c") translate([rete_x, fc_y, fondo + fc_alt]) fermacavo();
    if (tl_sul_coperchio) {
        color("#2b8a3e") translate([0, 0, ez + coperchio_h]) tl_su_coperchio() torretta_lcd();
        %translate([0, 0, ez + coperchio_h]) tl_su_coperchio() lcd_sagoma();
    } else translate([in_x + 40, 0, 0]) {          // scatolina display separata, accanto alla scatola
        color("#868e96") display_fondo();
        color("#2b8a3e") translate([0, 0, df_sp]) torretta_lcd();
        %translate([0, 0, df_sp]) lcd_sagoma();
    }
    // sagome (solo anteprima)
    %translate([psu_pos[0], psu_pos[1], fondo]) cube([psu_x, psu_y, psu_h]);
    %translate([bo_pos[0], bo_pos[1], fondo + bo_alt]) cube([bo_x, bo_y, 1.6]);
    %translate([uln_pos[0], uln_pos[1], fondo + uln_aria]) cube([uln_x, uln_y, uln_sp]);
    %translate([pca_pos[0], pca_pos[1], fondo + pca_alt]) cube([pca_dim[0], pca_dim[1], 12]);
    %translate([bss_pos[0], bss_pos[1], fondo]) cube([bss_dim[0], bss_dim[1], 3]);
    %translate([pi_pos[0] + pi_gioco, pi_pos[1] + pi_gioco, ez + coperchio_h]) cube([pi_x, pi_y, 25]);
    %translate([rete_x, 30, fondo + rete_z]) rotate([90, 0, 0]) cylinder(d = 7, h = 40);
    %translate([sw_x - 10.5, -2.4 - 1, fondo + sw_z - 7.5]) cube([21, 22, 15]);
}

// ---------------------------------------------------------------- selezione (orientamento di stampa)
if      (parte == "assieme")   assieme();
else if (parte == "scatola")   scatola();
else if (parte == "coperchio") translate([0, 0, -ez]) coperchio();          // piano superiore in alto, appoggia sul piatto
else if (parte == "fermacavo") fermacavo();
else if (parte == "display_guscio") rotate([0, -90, 0]) torretta_lcd();    // stampato sul fianco: finestra e asole senza supporti
else if (parte == "display_fondo")  display_fondo();
