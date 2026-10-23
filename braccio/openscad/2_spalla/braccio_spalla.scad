// braccio_spalla.scad — Torretta della spalla + braccio (omero) del braccio telecamera
// Si avvita sul piatto rotante della base (4 viti M3x12 testa tonda, dadi gia' nelle sedi del piatto).
// Spalla: MG996R da un lato, vite M8x40 nel cuscinetto 608 dall'altro.
// Bilanciamento "a lunghezza zero": 2 molle 7x51 in parallelo + cordino su 2 rulli (A e C).
// Tutte le misure in mm. Modificare solo i parametri qui sotto.

/* [Parte da generare] */
parte = "assieme"; // [assieme, torretta, braccio, rullo, giogo]
angolo = 70;       // solo per l'assieme: angolo del braccio dalla verticale (28..100)

/* [Geometria spalla] */
H         = 88;    // altezza asse spalla sopra il piatto
a_molla   = 28;    // distanza rullo A sopra l'asse (braccio di leva molla)
b_molla   = [24, 28, 32]; // fori di attacco cordino sul braccio (taratura)
L_braccio = 150;   // distanza asse spalla - flangia gomito

/* [MG996R] */
s_l       = 40.7;  // lunghezza corpo
s_w       = 19.7;  // larghezza corpo
s_h       = 37;    // altezza corpo (fondo - faccia superiore)
s_asse    = 10.2;  // distanza asse scanalato dal lato corto vicino
s_aletta  = 7.9;   // distanza faccia superiore - faccia delle alette che appoggia
s_fori_l  = 49.5;  // interasse fori alette (lungo)
s_fori_w  = 10;    // interasse fori alette (corto)
corno_off = 6.5;   // faccia superiore servo -> faccia esterna squadretta tonda
corno_d   = 25.5;  // diametro sede squadretta tonda nel braccio
corno_inc = 1.5;   // profondita' sede squadretta

/* [Cuscinetto e vite M8] */
cusc_d    = 22.1;  // sede 608 (press-fit leggero)
cusc_h    = 7;
m8_foro   = 8.3;
m8_chiave = 13.3;  // sede testa esagonale (+gioco)
m8_testa  = 5.6;

/* [Struttura] */
base_d    = 80;    // diametro anello di base
base_h    = 18;
base_foro = 24;    // passaggio dado M8 della base rotante
m3_passo  = 46;    // fori M3 del piatto rotante (deve coincidere con attacco_passo di braccio_base.scad)
m3_foro   = 3.4;   // M3 passante (fissaggio torretta)
rullo_vite = 3.4;  // perno rulli: vite M3 passante nelle fiancate
rullo_foro = 3.6;  // foro del rullo: gira libero sulla M3
m3_testa  = 6.5;   // lamatura testa tonda M3 (ISO 7380, d 5,7)
m3_presa  = 5;     // spessore sotto la testa (vite M3x12)
sp_servo  = 5;     // spessore fiancata servo
sp_cusc   = 9.6;   // spessore fiancata cuscinetto (7 + 0,6 + labbro 2)
rullo_d   = 10;    // diametro rulli A e C
x_C       = -19;   // posizione rullo C (sopra le molle)
y_molle   = 5;     // meta' distanza tra le due molle

/* [Qualita'] */
$fn = 72;

// ---------------------------------------------------------------- quote derivate (asse Y = asse spalla)
y_hub0   = -10;                         // faccia lato cuscinetto del mozzo braccio
y_hub1   = 10;                          // faccia lato servo
y_corno  = y_hub1 - corno_inc;          // faccia squadretta a contatto col braccio
y_stop   = y_corno + corno_off;         // faccia superiore servo
y_ali    = y_stop + s_aletta;           // appoggio alette = faccia esterna fiancata servo
y_fs0    = y_ali - sp_servo;            // faccia interna fiancata servo
y_fc0    = y_hub0 - 1;                  // faccia interna fiancata cuscinetto
y_fc1    = y_fc0 - sp_cusc;             // faccia esterna
y_mid    = (y_fs0 + y_fc0) / 2;         // centro del vano (piano delle molle e del cordino)
z_A      = H + a_molla;
x_molle  = x_C - rullo_d / 2;           // asse molle (tangente posteriore del rullo C)
s_z1     = H + s_asse;                  // estremo alto corpo servo
s_z0     = s_z1 - s_l;                  // estremo basso
s_zc     = (s_z0 + s_z1) / 2;

echo(str("Vano tra le fiancate: ", y_fs0 - y_fc0, " mm (centro y=", y_mid, ")"));
echo(str("Lunghezza rulli: ", y_fs0 - y_fc0 - 1, " mm"));
echo(str("Vite rulli: M3 x ", ceil((y_ali - y_fc1 + 6) / 5) * 5));

// ---------------------------------------------------------------- profilo fiancata (piano XZ)
module profilo_fiancata() {
    hull() {
        translate([-15.5, base_h]) square([31, 8]);
        translate([0, H]) circle(r = 18);
        translate([0, z_A]) circle(r = 8);
        translate([x_C, z_A]) circle(r = 8);
    }
}
module fiancata(y0, y1) {   // estrude il profilo tra y0 e y1 (y0 < y1)
    translate([0, y1, 0]) rotate([90, 0, 0]) linear_extrude(y1 - y0) profilo_fiancata();
}
module foro_y(x, z, d, y0 = -60, y1 = 60) {
    translate([x, y1, z]) rotate([90, 0, 0]) cylinder(d = d, h = y1 - y0, $fn = 32);
}

// ---------------------------------------------------------------- torretta
module torretta() {
    difference() {
        union() {
            // anello di base
            cylinder(d = base_d, h = base_h, $fn = 120);
            // fiancate
            fiancata(y_fs0, y_ali);
            fiancata(y_fc1, y_fc0);
            // borchie viti alette (verso il vano)
            for (z = [s_zc - s_fori_l / 2, s_zc + s_fori_l / 2], x = [-s_fori_w / 2, s_fori_w / 2])
                translate([x, y_fs0 + 0.01, z]) rotate([90, 0, 0]) cylinder(d = 8, h = y_fs0 - (y_stop + 0.5), $fn = 32);
            // guance di ancoraggio molle (vite M3 orizzontale)
            for (y = [y_mid - y_molle - 7.5, y_mid + y_molle + 4.5])
                translate([x_molle - 4, y, base_h - 0.01]) cube([8, 3, 18]);
        }
        // passaggio centrale e fori M3 con lamatura
        translate([0, 0, -1]) cylinder(d = base_foro, h = base_h + 2);
        for (x = [-1, 1], y = [-1, 1])
            translate([x * m3_passo / 2, y * m3_passo / 2, -1]) {
                cylinder(d = m3_foro, h = base_h + 2, $fn = 32);
                translate([0, 0, 1 + m3_presa]) cylinder(d = m3_testa, h = base_h, $fn = 32);
            }
        // finestra corpo servo
        translate([-s_w / 2 - 0.3, y_fs0 - 1, s_z0 - 0.3]) cube([s_w + 0.6, sp_servo + 2, s_l + 0.6]);
        // fori pilota viti alette (M3x10 avvitate nella plastica)
        for (z = [s_zc - s_fori_l / 2, s_zc + s_fori_l / 2], x = [-s_fori_w / 2, s_fori_w / 2])
            foro_y(x, z, 2.5, y_stop, y_ali + 1);
        // sede cuscinetto 608 (dal lato del vano) + labbro esterno
        foro_y(0, H, cusc_d, y_fc0 - cusc_h - 0.6, y_fc0 + 1);
        foro_y(0, H, 17, y_fc1 - 1, y_fc0);
        // fori rulli A e C
        foro_y(0, z_A, rullo_vite);
        foro_y(x_C, z_A, rullo_vite);
        // fori vite M3 delle guance (3 posizioni di pretensione)
        for (z = [base_h + 6, base_h + 10, base_h + 14]) foro_y(x_molle, z, 3.4);
    }
}

// ---------------------------------------------------------------- braccio (sistema locale: asse spalla = origine, braccio lungo +X)
module braccio() {
    difference() {
        union() {
            // mozzo + trave diritta 20x16 (stretta vicino al mozzo per passare sotto il rullo A)
            translate([0, y_hub1, 0]) rotate([90, 0, 0]) cylinder(r = 14, h = y_hub1 - y_hub0);
            translate([0, y_hub0, -8]) cube([L_braccio, y_hub1 - y_hub0, 16]);
            translate([L_braccio - 18, y_hub0, -8]) cube([18 + 0.01, y_hub1 - y_hub0, 16]);
        }
        // foro vite M8 + sede testa esagonale (sotto la squadretta)
        translate([0, 30, 0]) rotate([90, 0, 0]) cylinder(d = m8_foro, h = 60, $fn = 48);
        translate([0, y_corno + 0.01, 0]) rotate([90, 0, 0]) rotate(30)
            cylinder(d = m8_chiave / cos(30), h = m8_testa, $fn = 6);
        // sede squadretta tonda
        translate([0, y_hub1 + 0.01, 0]) rotate([90, 0, 0]) cylinder(d = corno_d, h = corno_inc + 0.01);
        // fori attacco cordino (attraverso lo spessore)
        for (b = b_molla) translate([b, 0, -10]) cylinder(d = 3, h = 20, $fn = 24);
        // alleggerimento
        hull() for (x = [48, L_braccio - 32]) translate([x, 20, 0]) rotate([90, 0, 0]) cylinder(d = 8, h = 40, $fn = 32);
        // innesto gomito: 2 fori M3 passanti nello spessore (viti M3x35 attraverso il supporto gomito)
        for (y = [-5, 5]) translate([L_braccio - 7, y, -20]) cylinder(d = 3.4, h = 40, $fn = 24);
    }
}

// ---------------------------------------------------------------- piccole parti
module rullo() {
    l = y_fs0 - y_fc0 - 1;
    difference() {
        cylinder(d = rullo_d, h = l);
        translate([0, 0, -1]) cylinder(d = rullo_foro, h = l + 2, $fn = 32);   // perno M3
        // gola per il cordino
        translate([0, 0, l / 2]) rotate_extrude() translate([rullo_d / 2 + 0.6, 0]) circle(r = 1.2, $fn = 24);
    }
}
module giogo() {
    difference() {
        hull() for (y = [-y_molle - 3, y_molle + 3]) translate([0, y, 0]) cylinder(r = 3.5, h = 4);
        for (y = [-y_molle, y_molle]) translate([0, y, -1]) cylinder(d = 2.2, h = 6, $fn = 24);
        translate([0, 0, -1]) cylinder(d = 2.2, h = 6, $fn = 24);
    }
}

// ---------------------------------------------------------------- assieme
module mg996r() {
    color("dimgray") translate([-s_w / 2, y_stop, s_z0]) cube([s_w, s_h, s_l]);
    color("dimgray") translate([-s_w / 2, y_ali, s_zc - 27]) cube([s_w, 2.5, 54]);
    color("white") translate([0, y_stop + 0.01, H]) rotate([90, 0, 0]) cylinder(d = 24, h = y_stop - y_corno);
}
module assieme() {
    color("lightsteelblue") torretta();
    translate([0, 0, H]) rotate([0, -(90 - angolo), 0]) color("orange") braccio();
    mg996r();
    color("tomato") translate([0, y_fc0 - 0.5, z_A]) rotate([90, 0, 0]) translate([0, 0, -(y_fs0 - y_fc0 - 1)]) rullo();
    color("tomato") translate([x_C, y_fc0 - 0.5, z_A]) rotate([90, 0, 0]) translate([0, 0, -(y_fs0 - y_fc0 - 1)]) rullo();
    color("dimgray", 0.6) {
        translate([0, y_fc0 - 0.6, H]) rotate([90, 0, 0]) difference() { cylinder(d = 22, h = 7); translate([0, 0, -1]) cylinder(d = 8, h = 9); }
        translate([0, y_corno - m8_testa, H]) rotate([90, 0, 0]) cylinder(d = 8, h = 40);
    }
    // molle (alla lunghezza di lavoro per l'angolo indicato)
    d = norm([sin(angolo) * b_molla[1], 0, cos(angolo) * b_molla[1] - a_molla]);
    for (s = [-1, 1]) color("silver") translate([x_molle, y_mid + s * y_molle, base_h + 10])
        cylinder(d = 7, h = 35 + d);
}

// ---------------------------------------------------------------- selezione
if      (parte == "assieme")  assieme();
else if (parte == "torretta") torretta();
else if (parte == "braccio")  translate([0, 0, -y_hub0]) rotate([90, 0, 0]) braccio();   // stampa sul fianco
else if (parte == "rullo")    rullo();
else if (parte == "giogo")    giogo();
