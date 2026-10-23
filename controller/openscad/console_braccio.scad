// console_braccio.scad — Console remota da banco per il braccio telecamera
// 2 joystick KY-023 (sinistro: base + spalla, destro: gomito), 4 pulsanti 12x12 con tappo quadrato A14 (tilt / rotazione testa).
// Dentro: Arduino Nano che legge tutto e parla col Raspberry via USB (un solo cavo, porta anche l'alimentazione).
// Parti: guscio (stampato capovolto, piano superiore sul piatto), fondo, piastrina che tiene i pulsanti.
// Viti: tutte M3 testa tonda. Fondo: 4 x M3x8. Joystick: 4 x M3x6 ciascuno. Piastrina pulsanti: 2 x M3x6.
// Tutte le misure in mm.

/* [Parte da generare] */
parte = "assieme"; // [assieme, guscio, fondo, piastrina]

/* [Guscio] */
L     = 170;    // larghezza
P     = 90;     // profondita'
H     = 32;     // altezza totale (fondo compreso)
r_ang = 8;      // raggio angoli in pianta
par   = 2.4;    // pareti
cielo = 2.4;    // spessore piano superiore
fondo_h = 3;    // spessore fondo
pilota_m3 = 2.5;
passante_m3 = 3.4;

/* [Joystick KY-023] */
joy_x    = 52;          // distanza del centro joystick dal centro console
joy_foro = 26;          // foro nel piano per la cupola del joystick
joy_fori = [20.5, 26.5];// interasse fori della schedina (x, y) attorno al centro della leva: MISURARE
joy_alt  = 11.5;        // dal piano della schedina al sotto del coperchio: altezza della staffa metallica + 0,5 (MISURARE)
joy_pcb  = [26, 34];    // schedina (connettore a 5 pin verso il retro, +y)
joy_col_d = 6.5;

/* [Pulsanti 12x12 + tappo 10x10] */
pul_passo = 16;          // distanza dei 4 pulsanti dal centro della croce
pul_croce = [0, -2];     // centro della croce
tappo_foro = 10.6;       // foro quadrato per il tappo 10x10
pul_corpo  = 12.4;       // sede del corpo 12x12 sotto il piano
pul_sede   = 0.8;        // profondita' sede: il piano resta 1,6 attorno al tappo (tappo sporge ~3,4)
pul_h      = 3.5;        // altezza corpo pulsante
piast_sp   = 2.5;        // spessore piastrina di ritegno
piast_lato = 50;

/* [Arduino Nano] */
nano     = [18.0, 43.2];  // scheda
nano_alz = 2;             // appoggio: i componenti sotto la scheda restano liberi
usb_fin  = [12.5, 11];    // finestra USB nel retro (aperta in basso)

$fn = 48;

// ---------------------------------------------------------------- quote derivate
z_cielo = H - cielo;                         // sotto del piano superiore
z_pul   = z_cielo + pul_sede;                // faccia superiore del corpo pulsante
z_piast = z_pul - pul_h;                     // faccia superiore della piastrina
pulsanti = [[0, 1], [0, -1], [-1, 0], [1, 0]];   // su, giu, sinistra, destra
function pul_pos(p) = [pul_croce[0] + p[0] * pul_passo, pul_croce[1] + p[1] * pul_passo];
piast_viti = [[pul_croce[0] + 21, pul_croce[1] + 21], [pul_croce[0] - 21, pul_croce[1] - 21]];
col_fondo = [[-L / 2 + 8, -P / 2 + 8], [L / 2 - 8, -P / 2 + 8], [-L / 2 + 8, P / 2 - 8], [L / 2 - 8, P / 2 - 8]];
nano_y1 = P / 2 - par - 0.8;                 // bordo posteriore scheda Nano
nano_y0 = nano_y1 - nano[1];

module pianta(l, p, r, h) hull() for (i = [-1, 1], j = [-1, 1]) translate([i * (l / 2 - r), j * (p / 2 - r), 0]) cylinder(r = r, h = h);

// ---------------------------------------------------------------- guscio (sistema: fondo a z=0, piano superiore a z=H)
module guscio() {
    difference() {
        union() {
            difference() {
                translate([0, 0, fondo_h]) pianta(L, P, r_ang, H - fondo_h);
                translate([0, 0, fondo_h - 1]) pianta(L - 2 * par, P - 2 * par, r_ang - par, H - fondo_h - cielo + 1);
            }
            // colonne viti del fondo
            for (c = col_fondo) translate([c[0], c[1], fondo_h]) cylinder(d = 9, h = H - fondo_h - 0.1);
            // colonnine joystick
            for (s = [-1, 1], i = [-1, 1], j = [-1, 1])
                translate([s * joy_x + i * joy_fori[0] / 2, j * joy_fori[1] / 2, z_cielo - joy_alt]) cylinder(d = joy_col_d, h = joy_alt + 0.1);
            // borchie piastrina pulsanti
            for (v = piast_viti) translate([v[0], v[1], z_piast]) cylinder(d = 7, h = z_cielo - z_piast + 0.1);
        }
        // fori joystick
        for (s = [-1, 1]) translate([s * joy_x, 0, z_cielo - 1]) cylinder(d = joy_foro, h = cielo + 2, $fn = 96);
        // pulsanti: foro tappo + sede corpo
        for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], 0]) {
            translate([-tappo_foro / 2, -tappo_foro / 2, z_cielo - 1]) cube([tappo_foro, tappo_foro, cielo + 2]);
            translate([-pul_corpo / 2, -pul_corpo / 2, z_cielo - 1]) cube([pul_corpo, pul_corpo, pul_sede + 1]);
        }
        // fori pilota
        for (c = col_fondo) translate([c[0], c[1], fondo_h - 1]) cylinder(d = pilota_m3, h = 11);
        for (s = [-1, 1], i = [-1, 1], j = [-1, 1])
            translate([s * joy_x + i * joy_fori[0] / 2, j * joy_fori[1] / 2, z_cielo - joy_alt - 1]) cylinder(d = pilota_m3, h = joy_alt + 0.5, $fn = 24);
        for (v = piast_viti) translate([v[0], v[1], z_piast - 1]) cylinder(d = pilota_m3, h = z_cielo - z_piast + 1.6, $fn = 24);
        // finestra USB del Nano nel retro (aperta in basso)
        translate([-usb_fin[0] / 2, P / 2 - par - 1, fondo_h - 1]) cube([usb_fin[0], par + 2, usb_fin[1] + 1]);
        // scritte incise sul piano
        translate([0, 0, H - 0.6]) linear_extrude(1) {
            for (s = [-1, 1]) translate([s * joy_x, -joy_foro / 2 - 9]) text(s < 0 ? "BASE / SPALLA" : "GOMITO", size = 5, halign = "center", font = "Liberation Sans:style=Bold");
            translate([pul_croce[0], pul_croce[1] - pul_passo - 15]) text("TESTA", size = 5, halign = "center", font = "Liberation Sans:style=Bold");
        }
    }
}

// ---------------------------------------------------------------- fondo (stampato cosi', alette per il Nano verso l'alto)
module fondo() {
    difference() {
        union() {
            pianta(L, P, r_ang, fondo_h);
            // culla del Nano: due sponde con appoggio interno
            for (s = [-1, 1]) translate([s * (nano[0] / 2 + 0.3) + (s < 0 ? -2.4 : 0), nano_y0, fondo_h - 0.01]) cube([2.4, nano[1], nano_alz + 1.6 + 1.5]);
            for (s = [-1, 1]) translate([s * (nano[0] / 2 + 0.3) + (s < 0 ? 0 : -1.2), nano_y0, fondo_h - 0.01]) cube([1.2, nano[1], nano_alz]);
        }
        for (c = col_fondo) translate([c[0], c[1], -1]) cylinder(d = passante_m3, h = fondo_h + 2);
        // asole per due fascette sopra il Nano
        for (y = [nano_y0 + 8, nano_y1 - 12], s = [-1, 1]) translate([s * (nano[0] / 2 + 5) - 1.5, y, -1]) cube([3, 5, fondo_h + 2]);
        // incavi per piedini adesivi (d 10)
        for (c = col_fondo) translate([c[0] * 0.9, c[1] * 0.75, -0.01]) cylinder(d = 10.5, h = 0.6);
    }
}

// ---------------------------------------------------------------- piastrina che spinge i 4 pulsanti nelle loro sedi
module piastrina() {
    difference() {
        translate([pul_croce[0] - piast_lato / 2, pul_croce[1] - piast_lato / 2, 0]) cube([piast_lato, piast_lato, piast_sp]);
        for (v = piast_viti) translate([v[0], v[1], -1]) cylinder(d = passante_m3, h = piast_sp + 2);
        // asole per le zampette (passo 12,5 x 5) e per i fili
        for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], -1]) {
            for (s = [-1, 1]) translate([s * 6.25 - 1.5, -4.5, 0]) cube([3, 9, piast_sp + 2]);
            translate([-3, -3, 0]) cube([6, 6, piast_sp + 2]);
        }
    }
}

// ---------------------------------------------------------------- sagome (solo anteprima)
module sagome() {
    for (s = [-1, 1]) translate([s * joy_x, 0, z_cielo - joy_alt]) {
        translate([-joy_pcb[0] / 2, -joy_pcb[1] / 2, -1.6]) cube([joy_pcb[0], joy_pcb[1] + 6, 1.6]);
        translate([-8, -8, 0]) cube([16, 16, joy_alt - 0.5]);
        translate([0, 0, joy_alt + 3]) cylinder(d = 24, h = 10);
    }
    for (p = pulsanti) translate([pul_pos(p)[0], pul_pos(p)[1], z_piast]) {
        translate([-6, -6, 0]) cube([12, 12, pul_h]);
        translate([-5, -5, pul_h + 0.6]) cube([10, 10, 4.6]);
    }
    translate([-nano[0] / 2, nano_y0, fondo_h + nano_alz]) cube([nano[0], nano[1], 1.6]);
    translate([-4, nano_y1 - 9, fondo_h + nano_alz + 1.6]) cube([8, 10, 4]);
}

module assieme() {
    color("#1971c2") guscio();
    color("#868e96") fondo();
    color("#e8590c") translate([0, 0, z_piast - piast_sp]) piastrina();
    %sagome();
}

// ---------------------------------------------------------------- selezione (orientamento di stampa)
if      (parte == "assieme")   assieme();
else if (parte == "guscio")    translate([0, 0, H]) rotate([180, 0, 0]) guscio();   // capovolto: piano superiore sul piatto
else if (parte == "fondo")     fondo();
else if (parte == "piastrina") piastrina();
