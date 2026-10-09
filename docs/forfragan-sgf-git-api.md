# Förfrågan till Svenska Golfförbundet om GIT API-licens

Utkast att skicka från Ludvig. Kontaktvägen finns på sidan "Licenser för GIT API för golfklubbar och företag" på klubb.golf.se. Skicka via den, eller fråga via golf.se/kontakt vilken adress som gäller.

---

**Ämne:** Förfrågan om kommersiell GIT API-licens för bokningsappen TeeTime

Hej!

Jag heter Ludvig Bohlin och utvecklar TeeTime, en app för golfare. I appen kan man boka starttider, bjuda in golfvänner till en tid (de svarar ja, kanske eller nej och bokningen görs med ett tryck) och få besked när en full tid blir ledig.

Vi vill att svenska golfare ska kunna använda sitt Golf-ID i TeeTime och boka tider på sina klubbar. Jag har läst er sida om licensmodellerna för GIT API och vill inleda en dialog om en kommersiell utvecklarlicens.

Det vi vill använda:

1. **Inloggning med Golf-ID** (Kontroll av Golfens inloggning).
2. **Klubb- och banuppgifter**: banor, slingor, slope och starttidsintervall.
3. **Starttider och bokning**: visa lediga tider samt boka och avboka för inloggad spelare på klubbar som har lagt till TeeTime som bokningssystem.
4. **Handicap** för inloggad spelare.
5. **Webhooks för bokningar** så att vi kan berätta för spelare när en tid blir ledig, utan att fråga efter tider i onödan.

Frågor:

- Vilka licenspaket passar för detta, och vad kostar start- och årsavgift?
- Hur ser ni på funktionen "säg till när en full tid blir ledig"? Vi vill bygga den på era webhooks och följa era regler om bevakning av starttider. Vad är tillåtet?
- Hur går godkännande och test i stage-miljön till, och hur lång tid tar det normalt?
- Behöver varje klubb aktivera TeeTime separat, och finns det ett standardförfarande för det?

Vi kan gärna ses digitalt och visa appen.

Vänliga hälsningar
Ludvig Bohlin
TeeTime
ludvig.j.bohlin@gmail.com
