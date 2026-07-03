# App Feature Review — Performance Windows Field Sales App (v5.4.14)

A walkthrough and feature summary of the Performance Windows mobile app, based on in-app screenshots captured July 2026. In short, the app is a door-to-door sales operating system: part CRM, part canvassing tracker, part leaderboard, part digital business card, and part training/library hub.

---

## 1. Main Navigation Structure

The app uses a bottom navigation bar with several major areas:

| Tab / Icon | Section | Purpose |
|---|---|---|
| Home | Dashboard | Quick access to daily sales tools |
| Trophy | Leaderboard | Team and rep performance rankings |
| Dollar sign | Sell (CRM) | Map, leads, card, calendar |
| Medal | Goals / Achievements | Milestones, badges, performance goals |
| Menu | More | Settings, library, reports, profile, links |
| Sparkle button (floating) | Assistant / shortcut | Smart assistant or quick-action widget |

---

## 2. Home Dashboard

The Home page is built around quick-access tiles.

**Visible widgets**

| Widget | Function |
|---|---|
| Golden Door Tracker (Milestone banner) | Milestone tracker, likely for knock count or a sales achievement |
| Quick Actions grid | Fast shortcuts for common field actions |
| Bottom tab bar | Persistent navigation |
| Three-dot menu | Extra settings/actions for the Home page |

**Quick Actions shown** (large action cards, two per row):

- Start Knocking
- Log Lead
- See Reports
- View Library
- Send a Message
- View My Card
- Add an Event
- View My Profile

This layout works well for field reps because it keeps the most common canvassing actions one tap away — no mental clutter.

---

## 3. More Menu

The More drawer provides admin, support, and secondary features.

**Top buttons:** Help, Feedback, Updates.

**Menu items**

| Item | Purpose |
|---|---|
| Library | Training documents, scripts, videos, product info |
| Messages | Internal/team communication |
| Reports | Performance analytics |
| Profile | Personal profile and sales identity |
| My Card | Digital business card / QR contact card |
| External Links | Company resources outside the app |
| Partner Portal | Vendor/partner/company portal access |
| Goals | Sales targets, incentives, milestones |
| Logout | Sign out |

App version shown in the footer: **Performance Windows (5.4.14)**.

---

## 4. Leaderboard System

The app has a strong gamification layer. A dismissible banner ("Get Paid To Refer Enzy") suggests the platform is built on **Enzy**, a door-to-door sales engagement product.

**Filters:** date range (Today), metric (Knocks), scope (Team / Rep).

**Company-wide totals visible (Today):**

| Metric | Value |
|---|---|
| Knocks | 33,636 |
| Conversations | 12,386 |

**Team rankings by knocks (Today):**

| Rank | Team | Knocks |
|---|---|---|
| 1 | AZ - Phoenix | 2,085 |
| 2 | WA - Seattle | 1,836 |
| 3 | NM - Albuquerque | 1,741 |
| 4 | OH - Columbus | 1,639 |
| 5 | TX - San Antonio | 1,563 |
| 6 | TX - Houston East | 1,512 |
| 7 | IN - Indianapolis | 1,489 |
| 8 | TN - Nashville | 1,347 |
| 9 | TN - Knoxville | 1,246 |
| 10 | GA - Atlanta | 1,199 |
| 11 | MO - St. Louis | 1,173 |
| 12 | AZ - T... (cut off) | ~1,155 |
| 13 | CO - Denver North | 1,146 |

The same screen can be re-scoped to individual reps, ranking them by knock count. This creates direct, public competition — brutal but motivating, and effective for sales culture.

---

## 5. Sell / CRM Section

The Sell section is the core field-sales workspace. A segmented control at the top switches between:

- **Map**
- **Leads**
- **Card**
- **Calendar**

It combines territory management, lead tracking, appointment management, and customer-facing identity tools in one place.

---

## 6. Leads Page

The Leads tab functions as a CRM list.

**Toolbar features**

| Feature | Purpose |
|---|---|
| Search bar | Search leads by name/address |
| Filter icon | Narrow leads by status, date, rep, etc. |
| Grid/list toggle | Change layout |
| Contact-add icon | Add or import a contact/lead |
| Plus button | Create a new lead |

**Each lead card includes:**

- Customer name with a verification/check badge
- Status dropdown (all visible leads showed **Appointment Scheduled**)
- Clickable address link (opens map/navigation)
- Next-appointment date/time card (e.g., "Jun 13, 2026 at 01:15 PM — Next Appointment")
- Closer assignment dropdown (visible leads showed **Unassigned**, highlighted in red)
- Setter field (Kurt shown as setter on all visible leads)

This centralizes the whole pipeline: who you talked to, where they live, when the appointment is, and who owns the next step. The red "Unassigned" closer state is a useful visual nudge that a lead still needs a handoff.

---

## 7. Map Page

The Map tab supports territory canvassing over a satellite view.

| Tool | Purpose |
|---|---|
| Satellite map view | Shows homes/neighborhood layout |
| Search button | Search an address or location |
| Filter button | Filter map pins/areas/leads |
| Insights drawer | Pull-up analytics panel |
| Map / Leads / Card / Calendar switcher | Move between sales workflows |

The map likely lets reps choose where to knock, mark doors, drop pins, and visualize territory.

---

## 8. Insights Panel

The pull-up Insights drawer gives user-level performance analytics.

**Filters**

| Filter | Options visible |
|---|---|
| User selector | Current rep (with teammate access note: "You have access to see stats for 48 teammates") |
| Date range | Today, Yesterday, This Week, Last Week |
| Refresh button | Updates stats |

**Stat cards ("Your Stats")**

| Stat | Meaning |
|---|---|
| Doors Knocked | Doors attempted |
| HO's Talked To | Homeowners spoken with |
| Leads Created (Sets) | Appointments/leads generated |
| Sits | Appointments that sat with a closer |
| Deals Submitted | Deals submitted/sold |
| Pins | Map pins created |
| Areas on Map | Territory areas assigned/marked |

In the screenshot all stats read 0 for the selected period (Today).

---

## 9. My Card / Digital Business Card

The app includes a polished digital business card system.

| Feature | Purpose |
|---|---|
| Name + company + photo | Personal branding |
| QR code | Scan to access contact/review/card link |
| "Authorized by Performance Windows" strip | Trust/verification |
| Contacts / Links toggle | Switch between contact info and links |
| Copy URL | Share the card link manually |
| Opens counter | Tracks how many times the card was opened |
| Reviews counter + rating | Tracks reviews generated (rating shows N/A until reviews exist) |
| Settings gear / refresh / link buttons | Configure, refresh stats, share |

This is one of the strongest features: a homeowner scans the QR, saves the rep's info, and can leave a review — a clean trust-building loop.

---

## 10. Profile Page

The Profile page displays the rep's identity, team, start date, and activity sections.

| Section | Purpose |
|---|---|
| Header photo | Personal/team profile image |
| Name + settings button | Identity and profile editing |
| Badges | Achievements |
| Goals | Personal sales goals |
| About | Basic profile info (name, team, start date) |
| Reports | Performance history |
| Media | Photos/videos/uploads |
| Notes | Internal notes |

The visible profile showed team **OK - Oklahoma City** with a May 2026 start date.

---

## 11. Edit Profile Page

Editable fields include preferred first/last name, phone, birthday, profile photo, and biography, followed by app settings. The biography field was flagged **Missing**, which suggests the app tracks profile completion.

---

## 12. Messaging, Reports, Library, and Goals

Visible in menus but not opened in the screenshots. Likely functions:

| Feature | Likely use |
|---|---|
| Messages | Team/company communication |
| Reports | Personal and team KPIs |
| Library | Scripts, training, documents, videos, product info |
| Goals | Daily/weekly/monthly sales goals |
| Updates | Company announcements |
| Partner Portal | External company/vendor tools |
| External Links | Quick access to company websites/resources |

---

## 13. The Sales Workflow the App Supports

1. Start Knocking
2. Use the Map to choose territory
3. Track doors knocked
4. Log homeowner conversations
5. Create a lead / set an appointment
6. Assign a closer
7. Track appointment status
8. Use the digital card / QR code for homeowner follow-up
9. Monitor performance through Insights
10. Compete on the Leaderboard
11. Use Library scripts to improve
12. Track goals, badges, and milestones

That is the complete field-sales loop.

---

## 14. Key Widgets and UI Components

| Widget type | Examples |
|---|---|
| Bottom navigation bar | Home, Leaderboard, Sell, Goals/Badges, More |
| Floating sparkle button | Assistant/help/shortcut tool |
| Quick-action cards | Start Knocking, Log Lead, See Reports, View Library |
| Segmented tabs | Map, Leads, Card, Calendar |
| Leaderboard filters | Today, Knocks, Team/Rep |
| Performance stat cards | Doors Knocked, HO's Talked To, Sets, Sits |
| Lead cards | Name, address, appointment, status, closer, setter |
| Search bars | Leads and My Card sections |
| QR code card | Digital business card sharing |
| Profile-completion fields | Photo, biography, personal info |
| Refresh buttons | Card stats and Insights |
| Dropdowns | Status, closer assignment, user/team filters |
| Map overlay drawer | Pull-up Insights panel |

---

## 15. Strongest Features

1. **Start Knocking + Map integration** — connects physical territory with measurable activity.
2. **Lead pipeline view** — appointment status, closer assignment, setter, address, and next appointment on one card.
3. **Insights dashboard** — immediate feedback on output: knocks, conversations, sets, sits, deals.
4. **Leaderboard** — gamifies production and creates social pressure; ruthless but effective.
5. **Digital QR business card** — professionalism, contact sharing, reviews, homeowner trust.
6. **Library + Goals + Reports** — makes it more than a CRM; it is also a training and performance system.

---

## Plain-English Summary

This app is a field sales command center. It helps a rep know where to knock, log leads, manage appointments, track production, share a professional QR contact card, compete with other reps, review reports, access training, and manage their sales identity.

For a setter role, the most important sections are:

**Start Knocking → Map → Log Lead → Leads → My Card → Insights → Leaderboard.**

That is the money path. Everything else is support structure.
