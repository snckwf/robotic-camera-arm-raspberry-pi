// supporto_pcb.scad — Base elettronica del braccio telecamera
// Contiene: millefori 50x70, modulo ULN2003 e Raspberry Pi 4 nella custodia GeeekPi Armor (dual fan).
// v2: angolari SENZA labbri a scatto (il PCB scende libero),
//     culla per la custodia del Pi con 4 angolari bassi (porte libere) e asole per fascette/velcro.
// v3: gioco ridotto e fissaggio dei PCB con 4 viti autofilettanti M2 ciascuno nei fori d'angolo.
// Piastra da avvitare al ripiano con 4 viti da legno a testa svasata.
// Tutte le misure in mm. Modificare solo i parametri qui sotto.

/* [Millefori] */
mf_x        = 70;     // lunghezza millefori
mf_y        = 50;     // larghezza millefori
mf_sp       = 1.6;    // spessore millefori
mf_aria     = 7;      // spazio sotto la millefori (fili e rotaie lato saldature)

/* [Modulo ULN2003] */
uln_x       = 35;     // lunghezza modulo
uln_y       = 32;     // larghezza modulo
uln_sp      = 1.6;    // spessore PCB
uln_aria    = 4;      // spazio sotto il modulo (piedini saldati)
uln_dist    = 8;      // distanza tra millefori e modulo

/* [Fori di fissaggio M2 (centro foro dal bordo del PCB)] */
mf_foro_x   = 2.0;    // millefori 5x7: interasse fori 66 mm sul lato lungo
mf_foro_y   = 1.8;    // millefori 5x7: interasse fori 46,4 mm sul lato corto
uln_foro_x  = 2.5;    // ULN2003: misura col calibro (centro foro dal bordo corto)
uln_foro_y  = 2.5;    // ULN2003: misura col calibro (centro foro dal bordo lungo)
pilota_m2   = 1.6;    // foro pilota per autofilettante M2 nel PETG
prof_m2     = 6;      // profondita' foro pilota (viti M2x6..M2x8)

/* [Angolari PCB (senza labbri)] */
gioco       = 0.4;    // gioco per lato attorno ai PCB (le viti M2 fanno il resto)
parete      = 1.8;    // spessore pareti
braccio     = 8;      // lunghezza bracci
appoggio    = 3.5;    // quanto l'appoggio entra sotto il PCB
sopra       = 1.5;    // quanto le pareti superano il piano del PCB

/* [Custodia Raspberry Pi 4] */
pi_x        = 87;     // lunghezza custodia (Armor: 87)
pi_y        = 56;     // larghezza custodia (Armor: 56)
pi_gioco    = 1.5;    // gioco per lato
pi_parete   = 2.4;    // spessore angolari
pi_braccio  = 14;     // lunghezza bracci angolari (lascia libere le porte)
pi_h        = 10;     // altezza angolari sopra la piastra
pi_dist     = 8;      // distanza tra culla Pi e PCB
cinghia_l   = 12;     // asola cinghia velcro / fascetta (lunghezza)
cinghia_w   = 3;      // asola (larghezza)
cinghia_x   = 25;     // posizione asole dal bordo corto della custodia (fuori dagli angolari)

/* [Piastra] */
piastra_h   = 3;      // spessore piastra
margine     = 4;      // bordo attorno agli angolari
orecchia    = 9;      // orecchie laterali per le viti
vite_d      = 4.5;    // viti da legno 4 mm
vite_t      = 8.5;    // diametro testa svasata
fascetta_l  = 4;      // asola fascetta cavi (lunghezza)
fascetta_w  = 2.2;    // asola fascetta cavi (larghezza)

/* [Qualita'] */
$fn = 48;

// ---------------------------------------------------------------- quote derivate
est     = gioco + parete;                       // ingombro angolari PCB oltre il bordo
pest    = pi_gioco + pi_parete;                 // ingombro angolari Pi oltre la custodia
gruppo  = mf_x + uln_dist + uln_x;              // larghezza millefori + modulo
z_mf    = piastra_h + mf_aria;
z_uln   = piastra_h + uln_aria;

// culla Pi (lato GPIO verso la millefori, porte USB-C/HDMI verso il bordo)
pi_x0   = (gruppo - pi_x) / 2;
pi_y0   = 0;
// millefori e modulo sopra la culla
mf_y0   = pi_y0 + pi_y + pest + pi_dist + est;
uln_x0  = mf_x + uln_dist;
uln_y0  = mf_y0 + (mf_y - uln_y) / 2;

px0 = min(-est, pi_x0 - pest) - margine - orecchia;
px1 = max(gruppo + est, pi_x0 + pi_x + pest) + margine + orecchia;
py0 = pi_y0 - pest - margine;
py1 = mf_y0 + mf_y + est + margine;

// foro della millefori: colonna 1..24, riga 0..17 (riga 0 = A, lato y alto)
mf_fx0 = (mf_x - 23 * 2.54) / 2;
mf_fy0 = (mf_y - 17 * 2.54) / 2;
function foro(c, r) = [mf_fx0 + (c - 1) * 2.54, mf_y0 + mf_y - mf_fy0 - r * 2.54];

echo(str("Piastra: ", px1 - px0, " x ", py1 - py0, " mm"));
echo(str("Alloggio millefori: ", mf_x + 2 * gioco, " x ", mf_y + 2 * gioco));
echo(str("Alloggio ULN2003: ", uln_x + 2 * gioco, " x ", uln_y + 2 * gioco));
echo(str("Alloggio custodia Pi: ", pi_x + 2 * pi_gioco, " x ", pi_y + 2 * pi_gioco));

// ---------------------------------------------------------------- angolare PCB senza labbro (quadrante x>0, y>0)
module angolare(z_app, sp, fx, fy) {
    z_top = z_app + sp + sopra;
    ax = max(appoggio, fx + 2.4);    // l'appoggio si allarga per tenere il foro M2
    ay = max(appoggio, fy + 2.4);
    // appoggio sotto l'angolo del PCB con foro pilota M2 in corrispondenza del foro d'angolo
    difference() {
        translate([-gioco, -gioco, 0]) cube([ax + gioco, ay + gioco, z_app]);
        translate([fx, fy, z_app - prof_m2]) cylinder(d = pilota_m2, h = prof_m2 + 0.01, $fn = 20);
        translate([fx, fy, z_app - 0.6]) cylinder(d1 = pilota_m2, d2 = pilota_m2 + 1.2, h = 0.61, $fn = 20);   // invito
    }
    // due pareti verticali con smusso d'invito in cima (interno)
    difference() {
        union() {
            translate([-est, -est, 0]) cube([parete, braccio + est, z_top]);
            translate([-est, -est, 0]) cube([braccio + est, parete, z_top]);
        }
        // smusso 45 gradi sul bordo interno in alto: guida il PCB verso il basso
        // parete lungo y (faccia interna x = -gioco)
        translate([0, -est - 1, 0]) rotate([-90, 0, 0]) linear_extrude(braccio + est + 2)
            polygon([[-gioco + 0.01, -z_top - 0.01], [-gioco - 1, -z_top - 0.01], [-gioco + 0.01, -z_top + 1]]);
        // parete lungo x (faccia interna y = -gioco)
        translate([-est - 1, 0, 0]) rotate([90, 0, 90]) linear_extrude(braccio + est + 2)
            polygon([[-gioco + 0.01, z_top + 0.01], [-gioco - 1, z_top + 0.01], [-gioco + 0.01, z_top - 1]]);
    }
}

module quattro_angolari(ox, oy, lx, ly, z_app, sp, fx, fy) {
    translate([ox, oy, 0])                          angolare(z_app, sp, fx, fy);
    translate([ox + lx, oy, 0])      mirror([1, 0, 0]) angolare(z_app, sp, fx, fy);
    translate([ox, oy + ly, 0])      mirror([0, 1, 0]) angolare(z_app, sp, fx, fy);
    translate([ox + lx, oy + ly, 0]) mirror([1, 0, 0]) mirror([0, 1, 0]) angolare(z_app, sp, fx, fy);
}

// ---------------------------------------------------------------- angolare custodia Pi
module angolare_pi() {
    translate([-pest, -pest, 0]) cube([pi_parete, pi_braccio + pest, pi_h]);
    translate([-pest, -pest, 0]) cube([pi_braccio + pest, pi_parete, pi_h]);
}

module culla_pi() {
    translate([pi_x0, pi_y0, 0]) {
        angolare_pi();
        translate([pi_x, 0, 0])    mirror([1, 0, 0]) angolare_pi();
        translate([0, pi_y, 0])    mirror([0, 1, 0]) angolare_pi();
        translate([pi_x, pi_y, 0]) mirror([1, 0, 0]) mirror([0, 1, 0]) angolare_pi();
    }
}

// ---------------------------------------------------------------- piastra
module piastra() {
    difference() {
        hull() for (x = [px0 + 4, px1 - 4], y = [py0 + 4, py1 - 4])
            translate([x, y, 0]) cylinder(r = 4, h = piastra_h);
        // viti svasate nelle orecchie
        for (x = [px0 + orecchia / 2 + 1, px1 - orecchia / 2 - 1], y = [py0 + 10, py1 - 10])
            translate([x, y, -0.01]) {
                cylinder(d = vite_d, h = piastra_h + 1);
                translate([0, 0, piastra_h - (vite_t - vite_d) / 2 + 0.02])
                    cylinder(d1 = vite_d, d2 = vite_t, h = (vite_t - vite_d) / 2);
            }
        // asole cinghie della custodia Pi (subito fuori dai lati lunghi, vicino ai lati corti)
        for (x = [pi_x0 + cinghia_x, pi_x0 + pi_x - cinghia_x])
            for (y = [pi_y0 - pi_gioco - 1 - cinghia_w, pi_y0 + pi_y + pi_gioco + 1])
                translate([x - cinghia_l / 2, y, -1]) cube([cinghia_l, cinghia_w, piastra_h + 2]);
        // aerazione sotto la custodia
        for (i = [0:4]) translate([pi_x0 + 22 + i * 9.5, pi_y0 + 10, -1]) cube([5, pi_y - 20, piastra_h + 2]);
        // asole fascette: cavi servo lungo il bordo alto, cavo motore a destra del modulo
        for (x = [15, 40])
            for (dy = [0, 7]) translate([x - fascetta_l / 2, py1 - 2.5 - fascetta_w - dy, -1]) cube([fascetta_l, fascetta_w, piastra_h + 2]);
        for (dx = [0, 7]) translate([uln_x0 + uln_x + est + 2 + dx, uln_y0 + uln_y / 2 - fascetta_l / 2, -1])
            cube([fascetta_w, fascetta_l, piastra_h + 2]);
        // alleggerimento sotto la millefori
        translate([12, mf_y0 + 10, piastra_h - 1]) cube([mf_x - 24, mf_y - 20, 2]);
    }
}

// ---------------------------------------------------------------- assieme stampabile
module supporto() {
    piastra();
    culla_pi();
    quattro_angolari(0, mf_y0, mf_x, mf_y, z_mf, mf_sp, mf_foro_x, mf_foro_y);
    quattro_angolari(uln_x0, uln_y0, uln_x, uln_y, z_uln, uln_sp, uln_foro_x, uln_foro_y);
    // pilastrini di sostegno sotto la millefori
    for (p = [foro(12, 17) + [1.27, 0], foro(24, 9) + [1.27, 1.27]])
        translate([p[0], p[1], 0]) cylinder(d = 4, h = z_mf);
}

supporto();

// sagome per controllo (solo anteprima F5)
%translate([0, mf_y0, z_mf]) cube([mf_x, mf_y, mf_sp]);
%translate([uln_x0, uln_y0, z_uln]) cube([uln_x, uln_y, uln_sp]);
%translate([pi_x0, pi_y0, piastra_h]) cube([pi_x, pi_y, 25]);
