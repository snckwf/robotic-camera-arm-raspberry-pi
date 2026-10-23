// braccio_gomito.scad — Supporto gomito (MG996R) + avambraccio del braccio telecamera
// Il supporto calza sull'estremita' del braccio (omero 20x16) e si blocca con 2 viti M3x35.
// Lato servo: MG996R con squadretta tonda sull'avambraccio. Lato opposto: perno vite M3x16 testa tonda.
// Sistema locale = quello del braccio: asse spalla in x=0, braccio lungo +X, asse gomito parallelo a Y.
// Tutte le misure in mm. Modificare solo i parametri qui sotto.

/* [Parte da generare] */
parte = "assieme"; // [assieme, supporto, avambraccio]
piega = -60;       // solo per l'assieme: angolo avambraccio rispetto al braccio (-140..140)

/* [Quote braccio (devono coincidere con braccio_spalla.scad)] */
L_braccio = 150;   // estremita' del braccio
innesto   = 22;    // lunghezza della parte di braccio infilata nel supporto
x_viti    = L_braccio - 7;
y_viti    = 5;     // viti M3 a y = +/-5
br_y      = 10;    // meta' larghezza braccio
br_z      = 8;     // meta' spessore braccio

/* [Gomito] */
x_e       = 168;   // asse gomito
L_avamb   = 130;   // asse gomito -> flangia testa
gioco     = 0.2;

/* [MG996R (come la spalla)] */
s_l       = 40.7;
s_w       = 19.7;
s_asse    = 10.2;
s_aletta  = 7.9;
s_fori_l  = 49.5;
s_fori_w  = 10;
corno_off = 6.5;
corno_d   = 25.5;
corno_inc = 1.5;

/* [Struttura] */
sp_servo  = 5;
sp_perno  = 6;
h_z       = 16;    // meta' altezza del supporto (piano di stampa a z = -h_z)

/* [Qualita'] */
$fn = 72;

// ---------------------------------------------------------------- quote derivate (identiche alla spalla)
y_hub0  = -10;
y_hub1  = 10;
y_corno = y_hub1 - corno_inc;
y_stop  = y_corno + corno_off;      // faccia superiore servo
y_ali   = y_stop + s_aletta;        // faccia esterna fiancata servo
y_fs0   = y_ali - sp_servo;
y_fp0   = y_hub0 - 1;               // faccia interna fiancata perno
y_fp1   = y_fp0 - sp_perno;
s_x1    = x_e + s_asse;             // corpo servo lungo X, verso il braccio
s_x0    = s_x1 - s_l;
s_xc    = (s_x0 + s_x1) / 2;
x_ini   = L_braccio - innesto;      // inizio manicotto
x_fine  = L_braccio + 2;            // fondo manicotto

echo(str("Gioco mozzo-manicotto: ", x_e - 14 - x_fine, " mm"));

module foro_y(x, z, d, y0 = -60, y1 = 60) {
    translate([x, y1, z]) rotate([90, 0, 0]) cylinder(d = d, h = y1 - y0, $fn = 32);
}

// ---------------------------------------------------------------- supporto gomito
module supporto() {
    difference() {
        union() {
            // manicotto attorno all'estremita' del braccio
            translate([x_ini, y_fp1, -h_z]) cube([x_fine - x_ini, y_fs0 - y_fp1, 2 * h_z]);
            // fiancata servo
            hull() {
                translate([s_x0 - 11, y_fs0, -h_z]) cube([1, sp_servo, 2 * h_z]);
                translate([x_e, y_ali, 0]) rotate([90, 0, 0]) cylinder(r = h_z, h = sp_servo);
                translate([s_xc + s_fori_l / 2 + 5, y_fs0, -h_z]) cube([1, sp_servo, 2 * h_z]);
            }
            // fiancata perno
            hull() {
                translate([x_ini, y_fp1, -h_z]) cube([1, sp_perno, 2 * h_z]);
                translate([x_e, y_fp0, 0]) rotate([90, 0, 0]) cylinder(r = h_z, h = sp_perno);
            }
        }
        // sede del braccio (aperta verso la spalla)
        translate([x_ini - 1, -br_y - gioco, -br_z - gioco]) cube([L_braccio - x_ini + 1 + gioco, 2 * (br_y + gioco), 2 * (br_z + gioco)]);
        // parte superiore del servo che entra nel vano + finestra nella fiancata
        translate([s_x0 - 0.3, y_stop - 0.3, -s_w / 2 - 0.3]) cube([s_l + 0.6, y_ali - y_stop + 1.3, s_w + 0.6]);
        // fori pilota alette (M3x10 avvitate nella plastica)
        for (x = [s_xc - s_fori_l / 2, s_xc + s_fori_l / 2], z = [-s_fori_w / 2, s_fori_w / 2])
            foro_y(x, z, 2.5, y_fs0 - 1, y_ali + 1);
        // perno gomito: vite M3 avvitata nella fiancata
        foro_y(x_e, 0, 2.5, y_fp1 - 1, y_fp0 + 1);
        // smussi anteriori del manicotto (piu' corsa per l'avambraccio)
        for (s = [-1, 1]) translate([x_fine, y_fp0, s * h_z]) rotate([0, 45, 0]) translate([-3.5, 0, -3.5]) cube([7, y_fs0 - y_fp0, 7]);
        // vano per il mozzo dell'avambraccio
        translate([x_fine, y_fp0, -h_z - 1]) cube([60, y_fs0 - y_fp0, 2 * h_z + 2]);
        // viti M3x35 verticali: testa sopra (lamatura), dado sotto (sede esagonale)
        for (y = [-y_viti, y_viti]) translate([x_viti, y, 0]) {
            translate([0, 0, -h_z - 1]) cylinder(d = 3.4, h = 2 * h_z + 2, $fn = 24);
            translate([0, 0, h_z - 3]) cylinder(d = 6.5, h = 4, $fn = 32);
            translate([0, 0, -h_z - 0.01]) rotate(30) cylinder(d = 6.4 / cos(30), h = 3, $fn = 6);
        }
    }
}

// ---------------------------------------------------------------- avambraccio (locale: asse gomito = origine, lungo +X)
module avambraccio() {
    difference() {
        union() {
            translate([0, y_hub1, 0]) rotate([90, 0, 0]) cylinder(r = 14, h = y_hub1 - y_hub0);
            translate([0, y_hub0, -br_z]) cube([L_avamb, y_hub1 - y_hub0, 2 * br_z]);
        }
        // sede squadretta tonda
        translate([0, y_hub1 + 0.01, 0]) rotate([90, 0, 0]) cylinder(d = corno_d, h = corno_inc + 0.01);
        // foro del perno M3 (lato opposto): il mozzo gira sulla vite
        foro_y(0, 0, 3.4, y_hub0 - 1, 2);
        // alleggerimento
        hull() for (x = [24, L_avamb - 30]) translate([x, 20, 0]) rotate([90, 0, 0]) cylinder(d = 8, h = 40, $fn = 32);
        // innesto testa: 2 fori M3 nello spessore (stesso schema del braccio)
        for (y = [-y_viti, y_viti]) translate([L_avamb - 7, y, -20]) cylinder(d = 3.4, h = 40, $fn = 24);
    }
}

// ---------------------------------------------------------------- assieme
module mg996r() {
    color("dimgray") translate([s_x0, y_stop, -s_w / 2]) cube([s_l, 37, s_w]);
    color("dimgray") translate([s_xc - 27, y_ali, -s_w / 2]) cube([54, 2.5, s_w]);
    color("white") translate([x_e, y_stop + 0.01, 0]) rotate([90, 0, 0]) cylinder(d = 24, h = y_stop - y_corno);
}
module braccio_finale() {   // ultimo tratto del braccio, solo per riferimento
    color("orange", 0.5) translate([L_braccio - 40, -br_y, -br_z]) cube([40, 2 * br_y, 2 * br_z]);
}
module assieme() {
    braccio_finale();
    color("lightsteelblue") supporto();
    mg996r();
    color("gold") translate([x_e, 0, 0]) rotate([0, -piega, 0]) avambraccio();
}

// ---------------------------------------------------------------- selezione
if      (parte == "assieme")     assieme();
else if (parte == "supporto")    translate([0, 0, h_z]) supporto();                          // sul piano a z = -h_z
else if (parte == "avambraccio") translate([0, 0, -y_hub0]) rotate([90, 0, 0]) avambraccio(); // sul fianco
