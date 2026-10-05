# resources

  ###/ɡrimˈwär/

  # 📜 collections of resources,data,scripts and files

## 
W.I.P -- UNFINISHED
-- THIS SCRIPT IS FAR FROM FINISHED AND IS USED AS A PLACEHOLDER AT THE MOMENT, DO NOT RUN BLINDLY - YOU WILL MOST LIKELY BREAK YOUR SETUP SINCE
I MAY ADD THINGS FROM OTHER  LEFT OVER BASH SCRIPTS I PREVIOUSLY WROTE WHICH ARE HEAVILY OUTDATED NOW.
YOU'VE BEEN WARNED 
=================================================================
 
                                    N O T E S
 
 ┌│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┐
 │▓▓                                                                        ▓▓│
 │▓▓                                                                        ▓▓│
 └│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│┘


                                    N O T E S
 
# 📜 Security Guide: Analyze the Threat Model

## Table of Contents
-

---

## 🔍 Analyze the Threat Model

When approaching a system to secure, it's crucial to ask yourself a series of questions. Even if some of these questions seem trivial, simplifying the problem is essential for effective security.

- [ ] Why do you want to secure your server and services?
- [ ] How much security do you desire?
- [ ] How many devices, apps, software, and databases need securing?
- [ ] How much convenience are you willing to compromise for security? (People often prefer convenience over security.)
- [ ] What threats do you want to protect against?
- [ ] What are the specifics of your situation?
- [ ] Is physical access to your server/network a possible attack vector?
- [ ] Do you need to address known vulnerabilities in hardware, software, or libraries?
- [ ] How are you hosting it? Is it accessible from the public?
- [ ] Do you have a recovery plan if your security measures lock you out of your own server? (e.g., if you disabled root login or password-protected GRUB and deleted your SSH public key.)
Threat Modeling Resourcesλ
Here are various threat modeling resources if you want to go deeper in threat modeling.


Here are alternative resources and methodologies if LINDDUN doesn't suit you:

Online Operations Security: https://github.com/devbret/online-OPSEC
Microsoft's STRIDE: https://en.wikipedia.org/wiki/STRIDE_%28security%29 [Wikiless] [Archive.org]
PASTA: https://versprite.com/tag/pasta-threat-modeling/ [Archive.org]
Threat Modeling: 12 Available Methods: https://insights.sei.cmu.edu/blog/threat-modeling-12-available-methods [Archive.org]
Threat Modelling: https://www.geeksforgeeks.org/threat-modelling/ [Archive.org]
Evil-Maid and Tampering Notesλ
Your context needs to be taken into account.

Preventing an evil-maid attack attack or tampering might lead to bad consequences. Your adversary might then resort to other means to obtain the key.

On the other hand, allowing the attack but detecting it will not let your adversary know that you are aware of the tampering. You can then take steps safely to not reveal information and possibly leave.

See the Some last OPSEC thoughts section for some tips.
---
## 🗂️ ---
