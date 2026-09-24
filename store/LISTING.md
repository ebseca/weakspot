# Play Console listing pack

Answers for every screen of the submission wizard. The declarations are legal
attestations about the app; each answer below is checked against the code and
says why it is true.

---

## App details

| Field | Value |
|---|---|
| App name | `Weakspot` |
| Package name | `com.ebseca.weakspot` (permanent once uploaded) |
| Default language | English (United Kingdom) |
| App or game | **App** |
| Category | **Education** |
| Free or paid | **Free** |
| Contains ads | **No** |
| In-app purchases | **No** — see the note on Weakspot Pro below |

> **Weakspot Pro and in-app purchases.** The app has a "Subscribe now" button
> that charges nothing: it flips a local flag. There is no billing library in
> the app and no purchase flow, so the honest answer to "in-app purchases" is
> **No**. The card in the app says "Nothing is charged" and "This build has no
> payments in it". If real billing is ever added, this answer, the listing and
> the app UI all change together, and Play Billing is the only permitted route
> for digital features.

## Short description (max 80 characters)

```
Flashcards that find what you're worst at and drill it. Offline, no account.
```

## Full description (max 4000 characters)

```
Weakspot is a flashcard app that spends your time where it is needed: on the
cards you keep getting wrong.

MULTIPLE CHOICE, AIMED AT YOUR WEAK SPOTS

Every card remembers your last ten answers. Weakspot looks at those and asks
you about whatever you are currently worst at, choosing at random among the
weakest so you are never stuck grinding the same card ten times in a row. Get
a card right often enough and it stops coming up; slip on it again and it
comes back.

NEW MATERIAL WHEN YOU ARE READY FOR IT

About five unmastered cards are kept in play at once. Master one and the next
opens straight away, mid-session. A card you have never seen is shown to you
first — both sides, plus a hint — before you are ever asked it, so a lucky
first guess never counts as knowing something.

READING AND WRITING ARE DIFFERENT SKILLS

Recognising あ as "a" is not the same as producing あ from "a". Weakspot asks
both ways round and scores them separately, so you can see which direction is
holding you back.

THREE WAYS TO PLAY

• Practice — drills your weak spots over 10, 20 or 40 questions
• Timed — the same drilling against the clock
• Random — a straight shuffle, no targeting

After every run you see that run: every card it asked, worst first, with the
answers you gave. The whole-deck picture, a needs-work list and your reading
against writing split are one tap away.

MAKE A DECK ABOUT ANYTHING, WITH ANY AI

There is no AI built in and no API key to enter. Type what you want to learn —
"Thai consonants", "Spanish kitchen vocabulary", "chemical symbols" — and
Weakspot writes a prompt for you. Paste it into whichever AI you already use,
then paste the reply back. Weakspot checks the result and tells you plainly if
anything is wrong with it, such as answers shared by several cards.

Hiragana and katakana come built in.

COMPLETELY OFFLINE

No account, no ads, no analytics, and no network requests of any kind. The app
does not even ask for permission to use the internet. Everything you learn
stays on your device.

Weakspot is open source under the GNU GPL v3.0.
https://github.com/ebseca/weakspot
```

---

## Data safety declaration

The whole form should come out empty.

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |

Why that is true: the release manifest requests **no internet permission** and
no dangerous permissions at all (`aapt dump permissions` lists only the
app-private `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` AndroidX adds). All state
— libraries, answer history, settings — is written to local storage via
`shared_preferences` and removed on uninstall.

> "Collect" in Play's definition means transmitted off the device. Storing
> data locally is not collection. Copying a prompt to the clipboard, or reading
> a file the user explicitly picks, is not collection either.

## App access

**All functionality is available without special access.** No login, no
credentials.

## Ads

**No, my app does not contain ads.**

## Content rating questionnaire

Category: **Reference, News, or Educational**

Category chosen: **All Other App Types**. Every content question is **No**
except "primarily a news or educational product", which is **Yes**: no
ratings-relevant content, no user interaction, no age-restricted goods, no
location sharing, no digital purchases (Pro is free), no cash rewards or NFTs,
not a browser.

> **"Content not in the initial download, e.g. generated AI content": No.**
> This is the one that needs thought. The app fetches nothing and has no AI;
> the user pastes text they obtained elsewhere, and it stays on their own
> device. Nothing is featured, promoted or served by the app.

Result as submitted: ClassInd all ages, ESRB Everyone, PEGI 3, USK all ages.

> **User-generated content:** decks a user makes stay on their own device and
> are never shared with anyone, so there is no UGC in Play's sense (content
> other users can see).


## Target audience and content

- Target age group: **13–15, 16–17, 18+** — not under-13, which pulls the app
  into the Families programme for no benefit
- Appeals to children: **No**

## Other declarations

| Declaration | Answer |
|---|---|
| Government app | No |
| Financial features | None |
| Health app | No |
| News app | No |
| Data deletion URL | Not applicable — no data is collected |

## Contact details

- **Email** — required, shown publicly on the listing
- **Website** — `https://github.com/ebseca/weakspot`
- **Privacy policy** — `https://ebseca.github.io/weakspot/`
