# TeeTime

Golfapp för att boka starttider, bevaka fulla tider och skicka tidsförslag till golfvänner. Webbapp (PWA) som körs på GitHub Pages med Supabase som databas, inloggning och notiser. Byggd på samma sätt som Familybase.

- `index.html` – hela appen
- `sw.js` – fungerar utan nät, tar emot notiser i telefonen
- `manifest.webmanifest`, ikoner – gör att appen kan installeras på hemskärmen
- `supabase/functions/send-notification` – skickar push och mejl (Resend)
- `supabase/sql` – databassteg som körs i Supabase SQL Editor

## Funktioner
- Inloggning med e-post och lösenord, byta e-post och lösenord, radera konto
- Flera klubbar med egna banor, priser, starttider och bokningsregler
- Tee-sheet per dag med lediga platser, öppna grupper, stängda tider och solnedgång
- Bokning med medspelare och bokningskod. Databasen låser starttiden så att två personer inte kan få samma plats.
- Bevaka exakt tid, ±30 min, ±1 tim eller hela dagen, med push och mejl när tiden blir ledig
- Golfvänner (sök på namn, vänkod eller länk) och tidsförslag med ja/kanske/nej, som bokas med ett tryck
- Notiser i appen, i telefonen och via mejl. Påminnelse kvällen före.
- Klubbadmin: startlista, avboka åt spelare, stänga tider, banor och priser, fler administratörer
- Direktuppdatering, sparad data utan nät, mörkt läge, större text

## Inställningar i Supabase
1. Authentication → URL Configuration: Site URL `https://ludvigjbohlin-afk.github.io/TeeTime/` och samma adress under Redirect URLs.
2. Edge Functions → Secrets: `RESEND_API_KEY` (från resend.com). Valfritt: `EMAIL_FROM`, till exempel `TeeTime <tider@dindomän.se>`, när en domän är verifierad i Resend.
