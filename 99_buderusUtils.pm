# $Id: 99_buderusUtils.pm 2021-10-17 Beta-User $

package main;

use strict;
use warnings;

sub buderusUtils_Initialize
{
  my $hash = shift;
}

# Enter you functions below _this_ line.

###### Boilerstatus ######
sub BoilerStatus {
  my $servicecode = shift // return 'no serviceCode provided!';
  my $servicecodenumber = shift // return 'no serviceCodeNumber provided!';
  return 'Heizbetrieb' if $servicecode eq '-H' && $servicecodenumber == '200';
  return 'Schornsteinfegerbetrieb oder Servicebetrieb' if $servicecode eq '-A' && $servicecodenumber == '208';
  return 'Warmwasserbetrieb' if $servicecode eq '=H' && $servicecodenumber == '201';
  my $err = "Unbekannte Kombination: Code $servicecode - Nummer $servicecodenumber";
  my $scn_codes = {
      '0A' => {
        202 => 'Leistungseinstellung am Basiscontroller prüfen oder Regelungseinstellungen im Regelgerät Bedieneinheit prüfen',
        203 => 'Innerhalb der eingestellten Schaltoptimierungszeit besteht eine erneute Brenneranforderung. Gerät befindet sich in Taktsperre. Die Standart-Schaltoptimierungszeit beträgt 10 min.',
        2505 => 'Wärmeanforderung blockiert durch Antipendelzeit',
        305 => 'Der Kessel hat gerade die Warmwasserbereitung beendet und befindet sich in der Nachlaufzeit (min 30 sec. max. 1 min.) und kann daher nicht starten.',
        333 => 'Der Kessel hat wegen kurzzeitig zu geringem Wasserdruck abgeschaltet.'
        },
      '0C' => {
         283 => 'Der Brenner wird gestartet.',
         2517 => 'Vorbelüftung',
         2518 => 'Warten, dass Mischraumtemperatur erreicht wird',
         2519 => 'Flamme bilden',
         2524 => 'Nachfackelkontrolle aus Startphase',
        },
      '0D' => {
        2525 => 'Nachfackelkontrolle aus Stationärbetrieb',
        2526 => 'Nachbelüftung aus Startphase',
        2527 => 'Nachbelüftung aus Stationärbetrieb',
        2528 => 'Gebläse aus',
        2529 => 'Sicherheitsrelais aus'
      },
      '0E' => {
	265 => 'Wärmeerzeuger in Bereitschaft und Wärmebedarf vorhanden, es wird jedoch zu viel Energie geliefert',
	2512 => 'Wärmeanforderung blockiert aufgrund einer Leistungsbegrenzung'
      },
      '0F' => {
    	'-' => 'Zu geringer Durchfluss durch den Wärmeerzeuger',
    	2513 =>'Wärmeanforderung blockiert aufgrund zu hoher Temperaturdifferenzen zwischen Vorlauf und Rücklauf'
      },
      '0H' => {
    	203 => 'Betriebsbereitschaft keine Waermeanforderung vorhanden',
	2500 => 'Keine Wärmeanforderung',
	2530 => 'Interner Status'
      },
      '0L' => {
    	284 => 'Die Gasarmatur wird angesteuert',
    	2520 => 'Flamme stabilisiieren',
	2521 => 'Stabilisieren Wärmetauscher',
	2522 => 'Warten Aufheizen Wärmetauscher',
	2523 => 'Umschaltphase ( von Start auf stationär )'
      },
      '0P' => {
    	205 => 'Der Kessel wartet auf Luftströmung'
      },
      '0U' => {
    	270 => 'Das Heizgeraet wird hochgefahren'
      },	
      '0Y' => {
    	204 => 'Die aktuelle Kesselwassertemperatur ist höher als die Sollkesselwassertemperatur. Der Kessel wird abgeschaltet.',
	276 => 'Die für den Vorlaufsensor fest vorgegebene Maximaltempertur von 95°C wurde überschritten.',
	277 => 'Die für den Vorlaufsensor fest vorgegebene Maximaltempertur von 95°C wurde überschritten.',
	285 => 'Die für den Rücklaufsensor fest vorgegebene Maximaltempertur von 95°C wurde überschritten.',
	359 => 'Temperatur am Warmwasser-Temperaturfühler zu hoch',
	2511 => 'Wärmeanforderung blockiert, weil Luftklappenstellmotor ( GPA ) nicht kalibriert',
	2515 => 'Wärmeanforderung blockiert, weil Kessel warm genug',
	2531 => 'Wärmeanforderung blockiert weil Mischraum zu kalt ist',
      },
      '1C' => {
    	210 => 'Das Abgasthermostat hat angesprochen.',
	526 => 'Fühlerdifferenz Abgas zu groß'
      },	
      '1F' => {
    	525 => 'Sobald die Abgastemperatur 140°C erreicht, wird diese Fehlermeldung erzeugt.'
      },
      '1H' => {
    	530 => 'Abgastemperatur zu hoch',
	562 => 'Abgasaustrittsicherung zu hohe Temperatur',
	563 => 'Abgasaustrittsicherung zu häufig'
      },
      '1L' => {
    	211 => 'Der UBA verzeichnet keine Verbindung zu ungenutzten Kontakten 50 und 78.',
	527 => 'Fühleranschluss zwischen den Abgasfühlern',
	529 => 'Abgasfühler Kurzschluss'
      }	,
      '1P' => {
    	528 => 'Abgasfühler Bruch'
      },
      '2A' => {
    	531 => 'Wassermangel im Kessel'
      },
      EU => {
    	207 => 'Betriebsdruck zu niedrig',
	357 => 'Entlüftungsprogramm',
	358 => 'Entlüftungsprogramm'
      },
      '2F' => {
    	260 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur',
	271 => 'Temperaturunterschied zwischen Vorlauf- und Sicherheitssensor >15K',
	338 => 'Der Kessel musste nach 6 Starts abbrechen.',
	345 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur'
      },
      '2L' => {
    	266 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur',
    	329 => 'Die Umwälzpumpe konnte während des Pumpentests keine Druckerhöhung von 50 mbar erzeugen.'
      },
      '2P' => {
    	212 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur',
	341 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur',
	342 => 'Temperaturanstieg Warmwasserbetrieb zu schnell',
	564 => 'Temperaturanstieg Kesselfühler zu schnell (>70K/min)'
      },
      '2U' => {
    	213 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur',
	565 => 'Differenz Vorlauf zu Rücklauf zu groß (>40K)',
	575 => 'Vorlauf ISTB',
	2050 => '"Falschdurchströmung des Kessels'
      },
      '2Y' => {
    	281 => 'Die Umwälzpumpe erzeugt keinen Druckunterschied.',
	282 => 'Keine Drehzahlrückmeldung der Umwälzpumpe.',
	307 => 'Die Umwälzpumpe ist blockiert.',
	308 => 'Die Umwälzpumpe dreht ohne Widerstand.'
      },
      '3A' => {
    	264 => 'Der Lufttransport ist während der Betriebsphase ausgefallen.'
      },
      '3C' => {
    	217 => 'Kein Lufttransport nach x-Minuten',
	537 => 'Keine Drehzahl',
	538 => 'Gebläse viel zu langsam.',
	539 => 'Gebläsedrehzahl außerhalb des zulässigen Bereichs',
	540 => 'Gebläse zu schnell.',
	2036 => 'Gebläsedrehzahl entspricht nicht Sollwert',
	2037 => 'Startdrehzahl am Gebläse nicht erreicht',
	2046 => 'Mindestdrehzahl Gebläse unterschritten',
	2114 => 'Schwergängiges Gebläse. Das Ansteuer-Signal (PWM) des Gebläses passt nicht zur Drehzahl'
      },
      '3F' => {
    	273 => 'Lufttransport'
      },
      '3H' => {
    	535 => 'Lufttemperatur zu hoch'
      },
      '3L' => {
    	214 => 'Lufttransport'
      },
      '3P' => {
    	216 => 'Das Gebläse dreht nicht schnell genug.',
	560 => 'Der Luftdruckschalter meldet keinen Kontakt, obwohl das Gebläse eingeschaltet ist.',
	2035 => 'Luftklappenstellung entspricht nicht dem Sollwert',
	2042 => 'Heizpatronentemperatur entspricht nicht Vorgabe. Heizpatronentemperatur zu hoch',
	2083 => 'Positionskalibrierung Luftklappe fehlgeschlagen',
	2091 => 'Stellklappe schließt schwergängig. Der Strom des Luftklappenstellmotors (GPA) ist im oberen Anschlag zu hoch',
	2112 => 'Heizpatrone kühlt nach Abschaltung nicht ab'
      },
      '3U' => {
    	536 => 'Falsche Anbringung Luftsensor/Abgassensor'
      },
      '3Y' => {
    	215 => 'Das Gebläse dreht zu schnell.',
	559 => 'Der Luftdruckschalter fällt trotz ausgeschaltetem Gebläse nicht ab.'
      },
      '4A' => {
    	218 => 'Die Temperatur am Vorlaufsensor ist >105°C',
    	332 => 'Temperatur am Vorlaufsensor >110°C',
	505 => 'Innerhalb von 30 min wurde am STB kein Temperaturanstieg festgestellt.',
	506 => 'Temperaturanstieg am STB schneller als 20K/min',
	507 => 'STB-Auslösung im STB Test.',
	520 =>'Vorlauf-STB',
	575 => 'Kesselvorlauftemperatur hat maximal zulässigen Wert überschritten',
	700 => 'Werksauslieferungszustand',
	2038 => 'Solltemperatur im Mischraum nicht erreicht',
	2043 => 'Mischraumtemperatur entspricht nicht Vorgabe, Mischraumtemperatur zu niedrig oder zu hoch',
	2090 => 'Temperaturanstieg der Heizpatrone zu gering'
      },
      '4C' => {
    	224 => 'Die Temperaturfuehler im Heizgeraet messen eine Abweichende Temperatur'
      },
      '4E' => {
    	225 => 'Nur für GB132T: Temperaturdifferenz zwischen Vorlauf- und Sicherheitssensor zu groß. (Doppelsensor)',
	278 => 'Sensortest fehlgeschlagen'
      },
      '4F' => {
    	219 => 'Die Temperatur am Sicherheitssensor ist >95°C'
      },
      '4L' => {
    	220 => 'Sicherheitssensor-Kurzschluss oder Sicherheitssensor wärmer als 130°C'
      },
      '4P' => {
    	221 => 'Sicherheitssensor loser Kontakt oder defekt'
      },
      '4U' => {
    	222 => 'Vorlaufsensor-Kurzschluss',
	350 => 'Kurzschluss Vorlauftemperaturfühler',
	521 => 'Fühlerdifferenz zwischen Kesselfühler 1 und 2 zu groß.',
	522 => 'Kurzschluss zwischen Kesselfühler 1 und 2',
	524 => 'Kesselvorlauffühler Kurzschluss',
	532 => 'Netzspannung zeitweilig zu gering (unter 180Volt) oder EMV Probleme',
	2006 => 'Kurzschluss Mischraum-Temperaturfühler',
	2009 => 'Differenz zwischen Mischraum-Temperaturfühler 1 und 2 zu groß',
	2023 => 'Kurzschluss Fühler Heizpatrone',
	2100 => 'Kurzschluss Mischraum-Temperaturfühler'
      },
      '4Y' => {
    	223 => 'Vorlaufsensor loser Kontakt oder defekt.',
	351 => 'Unterbrechung Vorlauftemperaturfühler"',
	523 => 'Kesselvorlauffühler Unterbrechnung',
	2005 => 'Unterbrechung Mischraum-Temperaturfühler'
      },
      '5A' => {
    	275 => 'UBA im Testmodus.',
	507 => 'STB-Test erfolgreich durchgeführt.'
      },
      '5C' => {
    	226 => 'Kennzeichnung für Handterminal'
      },
      '5E' => {
    	586 => 'SAFe alter Softwarebestand'
      },
      EU => {
    	268 => 'Der Relaistest wurde in der Fachkundenebene der Bedieneinheit RC3x aktiviert.',
	310 => 'Keine Komunikation mit EMS Wärmeerzeuger',
	470 => 'Keine Komunikation mit dem Systemregler',
	2113 => 'Interne Störung',
	5204 => 'Wärmeanforderung wegen Relaistest'
      },
      '5L' => {
    	542 => 'Kommunikation mit SAFe unvollständig.',
	543 => 'Keine Kommunikation mit SAFe.',
	2051 => 'Sicherheits-Controller blockiert'
      },
      '5P' => {
    	552 => 'Zu viele Entriegelungen über Schnittstelle.'
      },
      '5U' => {
    	588 => 'Mehr als ein UM10 im System',
	582 => 'Keine Kommunikation mit UM10'
      },
      '5Y' => {
    	585 => 'Die Kommunikation ist fehlerfrei, aber das UM10 meldet sich nicht mehr.'
      },
      '6A' => {
    	227 => 'Brenner entzuendet nicht',
	504 => 'Brennerstörung (nicht EMS Brenner)',
	577 => 'Keine Flamme innerhalb der Sicherheitszeit.'
      },
      '6C' => {
    	228 => 'Ionisationsmeldung trotz nicht vorhandener Flamme.',
	306 => 'Ionisationsmessung nach Schließen des Gasventiles.',
	508 => 'Zu hoher Flammenfühlerstrom',
	509 => 'Eingang QRC defekt.',
	519 => 'Kein Flammenabriss Nachbelüftung.',
	576 => 'Ionisation innerhalb der Vorbelüftung > 0,9yA',
	2041 => 'Fremdlicht im Feuerraum während Nachbelüftung erkannt. Flamme erlischt nicht, nachdem Magnetventil Ölpumpe geschlossen'
      },
      '6L' => {
    	229 => 'Flamme während des Brennerbetriebes ausgefallen',
	512 => 'Flammenabriss innerhalb der Sicherheitszeit.',
	513 => 'Flammenabriss innerhalb der Nachzündzeit',
	514 => 'Flammenabriss innerhalb der Stabilierungszeit.',
	515 => 'Flammenabriss in Betrieb 1.+2. Stufe',
	516 => 'Flammenabriss Umschaltung 1. Stufe',
	517 => 'Flammenabriss in Betrieb 1. Stufe',
	518 => 'Flammenabriss Umschaltung 1. + 2. Stufe',
	548 => 'Zu viele Reputationen/Wiederanläufe.',
	553 => 'Zu viele Flammenabrisse',
	555 =>  'Flammenabriss innerhalb der Stabilisierungszeit',
	557 => 'Flammenabriss bei Hauptgas ein.',
	558 => 'Keine Bildung der Hauptflamme.',
	561 => '5-mal Power-Up (Spannungsunterbrechung während Brennerstart)',
	587 => 'Flammenabriss Stabilisierung Teillast'
      },
      '6P' => {
    	269 => 'Glühzünder zu lange eingeschaltet.'
      },
      '6U' => {
    	511 => 'Keine Flamme innerhalb der Sicherheitszeit.'
      },
      '6Y' => {
    	510 => 'Fremdlicht Vorbelüftung',
	2039 => 'Fremdlicht im Feuerungsraum während Vorbelüftung erkannt. Flamme wurde zu einem unzulässigen Zeitpunkt erkannt'
      },
      '7A' => {
    	550 => 'Die Netzspannung ist zu niedrig.',
	551 => 'Spannungsunterbrechung'
      },
      '7C' => {
    	231 => 'Waehrend einer Stoerung war eine kurze Stromunterbrechung'
      },
      '7H' => {
    	328 => 'Unterbrechung der Spannungsversorgung'
      },
      '7L' => {
    	261 => 'Zeitfehler bei erster Sicherheitszeit',
	280 => 'Zeitfehler bei Wiederanlaufversuch.'
      },
      '7P' => {
    	549 => 'Die Sicherheitskette hat geöffnet.'
      },
      '7U' => {
    	5052 => 'Maximale Einschaltdauer Zündtrafo überschritten'
      },
      '8L' => {
	534 => 'Kein Gasdruck oder zusätzlicher Abgasdruckbegrenzer (Druck ab 550 pa) hat geschaltet',
	579 => 'Kein Gasdruck'
      },
      '8P' => {
    	580 => 'Magnetventil 1 undicht.'
      },
      '8U' => {
    	364 => 'Magnetventil EV2 undicht',
	365 => 'Magnetventil EV1 undicht',
	581 => 'Magnetventil 2 undicht',
	583 => 'UM10 externe Verriegelung',
	584 => 'UM10 keine Rückmeldung',
	591 => 'Abgassperrklappe öffnet nicht innerhalb von 30 sec.',
	592 => 'Abgassperrklappe dauerhaft geöffnet.',
	593 => 'Brücke am Eingang Küchenlüfter fehlt. (Dunstabzughaube)'
      },
      '8Y' => {
    	232 => 'Ein externer Schaltkontakt, z.B. Temperaturwächter für Fußbodenheizung, hat angesprochen.',
	572 => 'Über die Klemme EV 1.2 wurde eine externe Verriegelung durchgeführt.',
	581 => 'Magnetventil 2 undicht.',
	583 => 'Umschaltmodul externe Verriegelung',
	589 => 'Die Klemme 15/16 am BRM10 hat die Brennerschleife unterbrochen.',
	590 => 'Sicherheitskette Druckschalter hat während des Betriebs geöffnet.',
	2514 => 'Wärmeanforderung blockiert wegen UM10'
      },
      '9A' => {
    	235 => 'KIM oder UBA defekt.'
      },
      '9A' => {
        237 => 'KIM oder UBA defekt oder Kurzschluss im Anschlusskabel der Gasarmatur.',
	267 => 'UBA defekt',
	272 => 'UBA defekt'
      },
      '9L' => {
    	230 => 'Fehler Regelventil',
	234 => 'Spule der Gasarmatur oder Anschlusskabel der Gasarmatur defekt.',
	238 => 'UBA ist defekt.'
      },
      '9P' => {
    	239 => 'KIM oder UBA3 defekt oder Kurzschluss im Anschlusskabel der Gasarmatur'
      },
      '9U' => {
    	230 => 'Modulationsspule defekt oder Drähte an der Spule lose.',
	233 => 'KIM oder UBA defekt.'
      },
      '9Y' => {
    	500 => 'Keine Spannung Sicherheitsrelais.',
	501 => 'Sicherheitsrelais hängt',
	502 => 'Keine Spannung Brennstoffrelais 1',
	503 => 'Brennstoffrelais 1 hängt',
	2000 => 'Störung im Feuerungsautomaten',
	2001 => 'Störung im Feuerungsautomaten',
	2002 => 'Störung im Feuerungsautomaten',
	2003 => 'Störung im Feuerungsautomaten'
      },
      A01 => {
    	594 => 'NTC anstelle Kodierbrücke angeschlossen',
	800 => 'Außenfühler defekt.',
	808 => 'Warmwasserfühler defekt.',
	809 => 'Warmwasserfühler 2 defekt.',
	810 => 'Warmwasser bleibt kalt.',
	811 => 'Thermische Desinfektion misslungen.',
	815 => 'Temperaturfühler hydraulische Weiche defekt. ( Pumpeneffizienzmodul )',
	816 => 'Keine Kommunikation mit EMS',
	817 => 'Lufttemperaturfühler defekt',
	818 => 'Wärmeerzeuger bleibt kalt',
	819 => 'Ölvorwärmung meldet Dauersignal',
	820 => 'Öl-Betriebstemperatur wird nicht erreicht',
	828 => 'Wasserdruckfühler defekt',
	845 => 'Hydraulische Konfiguration wird nicht unterstützt',
	3818 => 'Keine Buskommunikation zwischen LM10/IUM10 und Geräteelektronik UBA-H3'
      },
      A02 => {
    	816 => 'Keine Kommunikation mit BC10'
      },
      A03 => {
    	816 => 'Keine Buskommunikation zwischen LM10/IUM und UBA-H3'
      },
      A11 => {
    	801 => 'Interner Laufzeitfehler im RC3x',
	802 => 'Uhrzeit noch nicht eingestellt.',
	803 => 'Datum noch nicht eingestellt.',
	804 => 'Interner Fehler. (EEPROM-Fehler)',
	805 => 'Werte über die Schnittstelle liegen außerhalb der definierten Grenzen.',
	806 => 'Der Raumtemperaturfühler der Bedieneinheit ist defekt.',
	821 => 'Keine HK1 Bedieneinheit',
	822 => 'Keine HK2 Bedieneinheit',
	823 => 'Keine HK1 Bedieneinheit',
	824 => 'Keine HK2 Bedieneinheit',
	826 => 'Heizkreis 1-RC30 Bedieneinheit',
	827 => 'HK2-RC30 Bedieneinheit',
	828 => 'Wasserdrucksensor defekt.',
	1000 => 'Systemkonfigaration nicht bestätigt',
	1004 => 'Systemkonfigaration nicht bestätigt',
	1010 => 'Keine Kommunikation über BUS-Verbindung EMS plus',
	1030 => 'Interner Datenfehler, Regelgerät austauschen',
	1033 => 'Interner Datenfehler, Regelgerät austauschen',
	1034 => 'Interner Datenfehler, Regelgerät austauschen',
	1035 => 'Interner Datenfehler, Regelgerät austauschen',
	1036 => 'Interner Datenfehler, Regelgerät austauschen',
	1037 => 'Außentemperaturfühler def. Ersatzbetrieb Heizung aktiv',
	1038 => 'Datum/Zeit ungültiger Wert',
	1039 => 'Wärmeerzeuger nicht für Estrichtrocknung mit ungemischten Heizkreisen geeignet',
	1040 => 'Estrichtrocknung mit ungemischten Heizkreisen nur mit Gesamtanlage möglich',
	1041 => 'Spannungsausfall während Estrichtrocknung',
	1042 => 'Interner Fehler, Zugriff auf Uhrenbaustein blockiert'
      },
      A12 => {
    	815 => 'Weichenfühler defekt.',
	816 => 'WM10 nicht vorhanden bzw. keine Kommunikation mit dem Modul.'
      },
      A18 => {
    	825 => 'Falsche Adresse RC2x'
      },
      A51 => {
    	812 => 'Einstellung Solar falsch.',
	813 => 'Kollektorfühler defekt.',
	814 => 'Speicher unten, Fühler defekt.',
	816 => 'SM10 nicht vorhanden bzw. keine Kommunikation.'
      },
      AD1 => {
    	817 => 'Lufttemperatursensor defekt.',
	818 => 'Der Kessel bleibt kalt.',
	819 => 'Ölvorwärmer Dauersignal',
	820 => 'Öl zu kalt'
      },
      CA => {
    	286 => 'Temperatur am Rücklaufsensor zu hoch'
      },
      C0 => {
    	288 => 'Wasserdruck',
	289 => 'Wasserdruck',
	568 => 'Störung Wasserdrucksensor, Kabelbruch',
	569 => 'Störung Wasserdrucksensor, Kurzschluss'
      },
      CU => {
    	240 => 'Kurzschluss am Rücklaufsensor'
      },
      CY => {
    	241 => 'Rücklaufsensor loser Kontakt oder defekt',
	566 => 'Rücklauftemperatur <-5°C (Unterbrechnung)',
	567 => 'Rücklauftemperatur > 150°C (Kurzschluss)',
	573 => 'Vorlauftemperaturfühler Unterbrechnung (Temperatur <-5°C)',
	574 => 'Vorlauftemperaturfühler Kurzschluss (Temperatur >150°C)'
      },
      E1 => {
    	242 => 'Systemfehler',
	243 => 'Systemfehler',
	244 => 'Systemfehler',
	245 => 'Systemfehler',
	246 => 'Systemfehler',
	247 => 'Systemfehler',
	248 => 'Systemfehler',
	249 => 'Systemfehler',
	255 => 'Systemfehler',
	257 => 'Systemfehler'
      },
      EA => {
    	252 => 'Systemfehler',
	253 => 'Systemfehler'
      },
      EC => {
    	251 => 'Systemfehler',
	256 => 'Systemfehler'
      },
      EE => {
    	547 => 'BIM Programmierung',
	554 => 'Fehler EEPROM',
	601 => 'Messung Kesselwasser /STB-Fühler',
	602 => 'Messung Abgasfühler',
	603 => 'A/D Wandler',
	604 => 'Referenzspannung des Sicherheits yC falsch',
	605 => 'Referenzspannung falsch',
	606 => 'Fühlertest fehlgeschlagen.',
	607 => 'Fühlertest kommt nicht',
	608 => 'Unterschiedliche Vorlauftemperaturen',
	609 => 'Unterschiedliche Abgastemperaturen',
	610 => 'Sicherheits-yC verreigelt',
	611 => 'Sicherheits-yC im anderen State.',
	612 => 'Messungen Rücklauffühler',
	613 => 'Messungen Vorlauffühler',
	620 => 'Sicherheits-yC arbeitet nicht',
	621 => 'Schlechte Kommunikation mit Sicherheits-yC',
	622 => 'Sicherheits-yC nicht synchron',
	623 => 'Sicherheits-yC kommt nicht',
	626 => 'Elektrodenspannung falsch',
	627 => 'Eingang Ionisationsstrom defekt.',
	630 => 'Interner Fehler SAFe.',
	631 => 'Interner Fehler SAFe.',
	640 => 'Interner Fehler SAFe.',
	641 => 'Interner Fehler SAFe.',
	650 => 'Statezahl zu hoch',
	651 => 'Falsches BIM',
	652 => '8 Bit CRC',
	653 => 'Verriegelung kann sich nicht gemerkt werden.',
	654 => 'Kein EEPROM',
	655 => 'Verriegelung nicht lesbar.',
	656 => 'Verriegelung nicht schreibbar',
	657 => 'Verriegelungskennung ungültig',
	658 => 'Verriegelung CRC Fehler',
	659 => 'EEPROM defekt',
	660 => 'BIM Kommunikation gestört.',
	661 => 'BIM-CRC Fehler',
	xxx => 'Interner Fehler'
      },
      EF => {
    	254 => 'Systemfehler'
      },
      EH => {
    	250 => 'Systemfehler',
	258 => 'Systemfehler',
	262 => 'Systemfehler'
      },
      EL => {
    	259 => 'Systemfehler',
	279 => 'Systemfehler',
	290 => 'Systemfehler'
      },
      EP => {
	287 => 'Systemfehler'
      },
      EU => {
        690 => 'Relais im UM10 schaltet nicht nach Vorgabe.',
        691 => 'Rückmeldung von UM10, obwohl das Relais im UM10 nicht angesteuert wird',
        692=> 'UM10 - Interner Fehler',
        693=> 'UM10 - Interner Fehler',
        694=> 'UM10 - Interner Fehler',
        695=> 'UM10 - Interner Fehler',
        696=> 'UM10 - Interner Fehler',
        697=> 'UM10 - Interner Fehler',
	698=> 'UM10 - Interner Fehler',
        699=> 'UM10 - Interner Fehler'
      },
      EY => {
        263 => 'Systemfehler'
      },
      LP => {
        570 => 'Zu viele Entriegelungen über Schnittstelle.'
      },
      LL => {
	571 => 'Zu viele Wiederanläufe trotz Entriegelung'
      }
  };
  if ( defined $scn_codes->{$servicecode} ) { 
    return $err if !defined $scn_codes->{$servicecode}->{$servicecodenumber}; 
    return $scn_codes->{$servicecode}->{$servicecodenumber};
  }
  
  return 'Das Heizgeraet wird zurueckgesezt' if $servicecode eq 'rE';

  if ($servicecodenumber eq '') {
    my %scn_codes = (
      H01 => 'Wartungsmeldung / Abgastemperatur zu hoch',
      H02 => 'Gebläse zu langsam / Wartungsmeldung',
      H03 => 'Betriebsstunden abgelaufen / Wartungsmeldung',
      H04 => 'Niedriger Flammenstrom / Wartungsmeldung',
      H05 => 'Hoher Zündverzug / Wartungsmeldung',
      H06 => 'Häufiger Flammenabriss / Wartungsmeldung',
      H07 => 'Wasserdruck zu niedrig / Wartungsmeldung',
      H08 => 'Nach Datum / Wartungsmeldung',
      H09 => 'Falsche Pumpe / Wartungsmeldung',
      H10 => 'Hoher Flammenstrom / Wartungsmeldung',
      H11 => 'Unrealistische Werte vom SLS Fühler (Schichtladesensor) / Wartungsmeldung',
      H12 => 'Der Kessel stellt einen Defekt am Speicher fest. / Wartungsmeldung'
    );    
    return $err if !defined $scn_codes->{$servicecode}; 
    return $scn_codes->{$servicecode};
  }
  return $err;
}

1;
