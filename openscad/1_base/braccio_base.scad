// braccio_base.scad — Base rotante del braccio telecamera
// Perno: vite M8x60 testa esagonale + 2 cuscinetti 608 (8x22x7)
// Motore: 28BYJ-48 con pignone 17 denti -> corona 34 denti (riduzione 1:2)
// Homing: magnete al neodimio 6x3 nel piatto + modulo Hall KY-024 sulla base
// Tutte le misure in mm. Modificare solo i parametri qui sotto.

/* [Parte da generare] */
parte = "assieme"; // [assieme, base_fissa, piatto_rotante, pignone, distanziale, anellino]

/* [Cuscinetti 608] */
cusc_d        = 22;     // diametro esterno
cusc_h        = 7;      // spessore
cusc_gioco    = 0.1;    // press-fit leggero sul diametro della sede
cusc_battuta  = 19;     // diametro battuta anello esterno
anello_int_d  = 11.5;   // appoggio solo sull'anello interno (non tocca le guarnizioni)
distanza_cusc = 16;     // spazio tra i due cuscinetti nel mozzo

/* [Vite M8] */
testa_vite    = "esagonale"; // [esagonale, brugola]
m8_foro       = 8.4;    // foro passante M8
m8_chiave     = 13;     // chiave testa esagonale
m8_testa_h    = 5.3;    // altezza testa esagonale
m8_brugola_d  = 13.5;   // diametro testa a brugola (ISO 4762) + gioco
m8_brugola_h  = 8.2;    // altezza testa a brugola + gioco

/* [Piastra base] */
pb_x0         = -55;    // bordo sinistro (rispetto all'asse di rotazione)
pb_x1         = 82;     // bordo destro (lato motore)
pb_y          = 100;    // larghezza
pb_h          = 5;      // spessore piastra
pb_r          = 8;      // raggio angoli
boss_d        = 32;     // torretta centrale
boss_h        = 14;     // altezza torretta (piano superiore)
vite_legno_d  = 4.5;    // viti da legno per fissarla al ripiano
vite_legno_t  = 9;      // diametro testa svasata

/* [Piatto rotante] */
mozzo_d       = 30;
z_mozzo0      = 15.5;   // quota inferiore del mozzo
disco_d       = 90;
disco_h       = 7;      // sopra i dadi M3 restano 4,4 mm di disco
attacco_passo = 46;     // 4 fori M3 in quadrato per la torretta della spalla (dadi fuori dal distanziale della corona)
m3_foro       = 3.4;    // M3 passante
m3_dado       = 6.0;    // chiave dado M3 (5,5) + gioco
m3_dado_h     = 2.6;    // dado M3 alto 2,4
magnete_d     = 6.3;    // magnete 6x3 + gioco
magnete_h     = 3.2;
magnete_r     = 38;     // raggio della traccia magnete / sensore

/* [Ingranaggi] */
modulo        = 1.5;
z_corona      = 34;     // denti corona (sul piatto)
z_pignone     = 17;     // denti pignone (sul motore) -> 1:2
ingr_h        = 8;      // spessore dentatura corona
pignone_h     = 7;      // spessore pignone (1 mm di gioco sotto il distanziale della corona)
pign_tondo    = 2.5;    // tratto basso del foro tondo: l'albero del 28BYJ-48 ha i piatti solo negli ultimi 6 mm
z_ingr        = 26;     // quota inferiore dentatura
gioco_denti   = 0.15;   // gioco sullo spessore del dente

/* [Motore 28BYJ-48] */
mot_d         = 28;     // diametro corpo
mot_h         = 19;     // altezza corpo (fino al piano delle orecchie)
mot_off       = 8;      // eccentricita' albero rispetto al corpo
orecchie_int  = 35;     // interasse fori di fissaggio
orecchie_t    = 0.8;    // spessore orecchie
mot_vite      = 2.5;    // foro pilota: vite M3 avvitata nella plastica
albero_d      = 5;
albero_piatti = 3;      // distanza tra i piani dell'albero

/* [Sensore Hall KY-024] */
hall_x        = -38;    // sotto la traccia del magnete
hall_alt      = 22;     // quota piano del piedistallo (basso: trimmer e componenti restano sotto il piatto)
hall_lung     = 30;     // lunghezza piedistallo (lungo Y)
hall_largh    = 10;
hall_fori     = [-30, -22]; // posizioni Y dei fori pilota M3

/* [Qualita'] */
$fn = 96;

// ---------------------------------------------------------------- quote derivate
rp_corona   = modulo * z_corona / 2;
rp_pignone  = modulo * z_pignone / 2;
interasse   = rp_corona + rp_pignone;          // 38.25 con i valori standard
mot_x       = interasse + mot_off;              // centro corpo motore
z_c1        = boss_h + 1;                       // base cuscinetto inferiore
z_c2        = z_c1 + cusc_h + distanza_cusc;    // base cuscinetto superiore
z_top       = z_c2 + cusc_h;                    // piano superiore piatto (= cuscinetto a filo)
z_disco0    = z_top - disco_h;

echo(str("Interasse ingranaggi = ", interasse, " mm"));
echo(str("Piano superiore piatto a z = ", z_top, " mm"));
echo(str("Lunghezza distanziale = ", distanza_cusc, " mm"));

// ---------------------------------------------------------------- ingranaggio a evolvente
function inv(a) = tan(a) - a * PI / 180;        // a in gradi -> radianti
function gradi(x) = x * 180 / PI;

module ingranaggio(z, m, h, gioco = 0.15, pa = 20) {
    rp = m * z / 2;
    rb = rp * cos(pa);
    ra = rp + m;
    rf = rp - 1.25 * m;
    semi = PI / (2 * z) - (gioco / 2) / rp;     // meta' dente al primitivo (rad)
    base = semi + inv(pa);
    r0 = max(rb, rf);
    n = 12;
    fianco = [for (i = [0 : n]) let(r = r0 + (ra - r0) * i / n)
              [r, gradi(base - inv(acos(rb / r)))]];
    a0 = fianco[0][1];
    su = [for (p = fianco) [p[0] * cos(p[1]), p[0] * sin(p[1])]];
    giu = [for (i = [n : -1 : 0]) let(p = fianco[i]) [p[0] * cos(-p[1]), p[0] * sin(-p[1])]];
    radice = [[(rf - 0.4) * cos(-a0), (rf - 0.4) * sin(-a0)],
              [(rf - 0.4) * cos(a0),  (rf - 0.4) * sin(a0)]];
    linear_extrude(h)
        union() {
            circle(r = rf, $fn = z * 4);
            for (k = [0 : z - 1]) rotate(k * 360 / z)
                polygon(concat(giu, radice, su));
        }
}

// ---------------------------------------------------------------- base fissa
module piastra_2d() {
    hull()
        for (x = [pb_x0 + pb_r, pb_x1 - pb_r], y = [-pb_y / 2 + pb_r, pb_y / 2 - pb_r])
            translate([x, y]) circle(r = pb_r);
}

module base_fissa() {
    difference() {
        union() {
            linear_extrude(pb_h) piastra_2d();
            cylinder(d = boss_d, h = boss_h);
            // anello di appoggio sull'anello interno del cuscinetto inferiore
            translate([0, 0, boss_h - 0.01]) cylinder(d = anello_int_d, h = 1.01);
            // colonnine per le orecchie del motore
            for (s = [-1, 1])
                translate([mot_x, s * orecchie_int / 2, 0])
                    cylinder(d = 7, h = pb_h + mot_h - orecchie_t);
            // piedistallo sensore Hall
            translate([hall_x - hall_largh / 2, -hall_lung - 6, 0])
                cube([hall_largh, hall_lung, hall_alt]);
        }
        // sede testa vite M8 (dal basso) + foro passante con strato di sacrificio 0.3 mm
        if (testa_vite == "esagonale") {
            translate([0, 0, -0.01])
                cylinder(d = (m8_chiave + 0.4) / cos(30), h = m8_testa_h + 0.31, $fn = 6);
            translate([0, 0, m8_testa_h + 0.6]) cylinder(d = m8_foro, h = 50, $fn = 48);
        } else {
            translate([0, 0, -0.01]) cylinder(d = m8_brugola_d, h = m8_brugola_h + 0.01);
            translate([0, 0, m8_brugola_h + 0.3]) cylinder(d = m8_foro, h = 50, $fn = 48);
        }
        // fori pilota motore
        for (s = [-1, 1])
            translate([mot_x, s * orecchie_int / 2, pb_h])
                cylinder(d = mot_vite, h = mot_h, $fn = 32);
        // fori pilota M3 sensore
        for (y = hall_fori)
            translate([hall_x, y, hall_alt - 10]) cylinder(d = 2.5, h = 11, $fn = 32);
        // fori svasati per viti da legno
        for (x = [pb_x0 + 9, pb_x1 - 9], y = [-pb_y / 2 + 9, pb_y / 2 - 9])
            translate([x, y, -0.01]) {
                cylinder(d = vite_legno_d, h = pb_h + 1, $fn = 32);
                translate([0, 0, pb_h - (vite_legno_t - vite_legno_d) / 2 + 0.02])
                    cylinder(d1 = vite_legno_d, d2 = vite_legno_t, h = (vite_legno_t - vite_legno_d) / 2, $fn = 32);
            }
    }
}

// ---------------------------------------------------------------- piatto rotante
module piatto_rotante() {
    difference() {
        union() {
            translate([0, 0, z_mozzo0]) cylinder(d = mozzo_d, h = z_top - z_mozzo0);
            translate([0, 0, z_ingr]) ingranaggio(z_corona, modulo, ingr_h, gioco_denti);
            translate([0, 0, z_disco0]) cylinder(d = disco_d, h = disco_h, $fn = 180);
            // distanziale pieno tra corona e disco, largo quanto la testa dei denti:
            // stampando a testa in giu' (disco sul piatto) ogni strato e' sostenuto da quello sotto
            translate([0, 0, z_ingr + ingr_h - 0.01])
                cylinder(r = rp_corona + modulo, h = z_disco0 - z_ingr - ingr_h + 0.02, $fn = 180);
        }
        // foro centrale
        translate([0, 0, z_mozzo0 - 1]) cylinder(d = 16, h = z_top);
        // sede cuscinetto inferiore + battuta
        translate([0, 0, z_mozzo0 - 0.01]) cylinder(d = cusc_d + cusc_gioco, h = z_c1 + cusc_h - z_mozzo0 + 0.01);
        translate([0, 0, z_c1 + cusc_h - 0.01]) cylinder(d1 = cusc_battuta, d2 = 16, h = 1.5);
        // sede cuscinetto superiore + battuta
        translate([0, 0, z_c2]) cylinder(d = cusc_d + cusc_gioco, h = cusc_h + 0.01);
        // battuta a cono 45 gradi (nessun gradino piano): stampabile a testa in giu' senza sbalzi,
        // l'anello esterno del 608 appoggia sullo smusso
        translate([0, 0, z_c2 - (cusc_d + cusc_gioco - 16) / 2])
            cylinder(d1 = 16, d2 = cusc_d + cusc_gioco, h = (cusc_d + cusc_gioco - 16) / 2 + 0.01);
        // 4 fori M3 con sede dado sotto il disco
        for (x = [-1, 1], y = [-1, 1])
            translate([x * attacco_passo / 2, y * attacco_passo / 2, z_disco0 - 0.01]) {
                cylinder(d = m3_foro, h = disco_h + 1, $fn = 32);
                rotate(30) cylinder(d = m3_dado / cos(30), h = m3_dado_h, $fn = 6);
            }
        // sede magnete (sotto il disco, sopra il sensore in posizione di riposo)
        translate([hall_x, 0, z_disco0 - 0.01]) cylinder(d = magnete_d, h = magnete_h + 0.01, $fn = 48);
        // tacca di riferimento sul bordo (direzione +X = davanti)
        translate([disco_d / 2, 0, z_top]) rotate([0, 45, 0]) cube([2, 3, 2], center = true);
    }
}

// ---------------------------------------------------------------- pignone motore
module pignone() {
    difference() {
        ingranaggio(z_pignone, modulo, pignone_h, gioco_denti);
        // tratto basso tondo (l'albero e' tondo tra collarino e inizio dei piatti)
        translate([0, 0, -0.01]) cylinder(d = albero_d + 0.3, h = pign_tondo + 0.01, $fn = 48);
        // tratto alto sagomato sui piatti dell'albero
        translate([0, 0, pign_tondo - 0.01])
            intersection() {
                cylinder(d = albero_d + 0.2, h = pignone_h, $fn = 48);
                translate([-(albero_piatti + 0.2) / 2, -5, 0]) cube([albero_piatti + 0.2, 10, pignone_h]);
            }
    }
}

// ---------------------------------------------------------------- distanziali (solo anello interno)
module distanziale() {
    difference() {
        cylinder(d = anello_int_d, h = distanza_cusc);
        translate([0, 0, -1]) cylinder(d = m8_foro, h = distanza_cusc + 2, $fn = 48);
    }
}

module anellino() {
    difference() {
        cylinder(d = anello_int_d, h = 2);
        translate([0, 0, -1]) cylinder(d = m8_foro, h = 4, $fn = 48);
    }
}

// ---------------------------------------------------------------- assieme (con parti commerciali in trasparenza)
module cuscinetto_608() {
    difference() {
        cylinder(d = cusc_d, h = cusc_h);
        translate([0, 0, -1]) cylinder(d = 8, h = cusc_h + 2);
    }
}

module motore_28byj() {
    color("silver") cylinder(d = mot_d, h = mot_h);
    color("silver") translate([0, 0, mot_h - orecchie_t])
        linear_extrude(orecchie_t) hull() for (s = [-1, 1]) translate([0, s * orecchie_int / 2]) circle(d = 7);
    color("royalblue") translate([mot_d / 2 - 3, -8.5, 0]) cube([6, 17, mot_h - 1]);
    color("gold") translate([-mot_off, 0, mot_h]) cylinder(d = 9, h = 1.5);
    color("gold") translate([-mot_off, 0, mot_h]) cylinder(d = albero_d, h = 10);
}

module assieme() {
    color("lightsteelblue") base_fissa();
    color("orange") piatto_rotante();
    // con 17 denti (dispari) a 180 gradi c'e' gia' un vano: nessuna rotazione di fase
    color("tomato") translate([interasse, 0, z_ingr]) pignone();
    color("orange") translate([0, 0, z_c1 + cusc_h]) distanziale();
    color("orange") translate([0, 0, z_top]) anellino();
    translate([mot_x, 0, pb_h]) motore_28byj();
    color("dimgray", 0.6) {
        translate([0, 0, z_c1]) cuscinetto_608();
        translate([0, 0, z_c2]) cuscinetto_608();
        cylinder(d = 8, h = 60 + m8_testa_h);                                   // vite
        cylinder(d = m8_chiave / cos(30), h = m8_testa_h, $fn = 6);             // testa
        translate([0, 0, z_top + 2]) cylinder(d = 16, h = 1.6);                 // rondella
        translate([0, 0, z_top + 3.6]) cylinder(d = 13 / cos(30), h = 8, $fn = 6); // dado autobloccante
    }
    color("red") translate([hall_x, 0, z_disco0]) cylinder(d = 6, h = 3);    // magnete
    color("green") translate([hall_x - 7.5, -36, hall_alt]) cube([15, 36, 1.6]); // KY-024
}

// ---------------------------------------------------------------- selezione
if      (parte == "assieme")        assieme();
else if (parte == "base_fissa")     base_fissa();
else if (parte == "piatto_rotante") rotate([180, 0, 0]) translate([0, 0, -z_top]) piatto_rotante(); // disco sul piatto
else if (parte == "pignone")        pignone();
else if (parte == "distanziale")    distanziale();
else if (parte == "anellino")       anellino();
