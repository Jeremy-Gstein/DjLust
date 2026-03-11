# DjLust 
A Simple WoW Addon to Play music and display an animation during Bloodlust and other similar spells.

**Combat 'state' tracked using players relative haste percentage by sampling every 0.3 seconds.**

## Usage:
- Click the new bloodlust icon on your minimap to bring up settings menu OR use the following commands
- `/djlust` - Prints available commands to the chat. 
- `/djlust settings` - Open Settings Menu
<sub> `/djl` available alias for `/djlust` </sub>

## Features:
- Choose Between 2 Default Music Clips
- Choose Between 2 Animations OR Optionally Configure Custom Text to display
- Dont like sound? Select `none` under Music and only see the Animation.
- Dont like seeing anything on screen? Hide the Animation and only hear the Sound track.

**Commands:**
- `/djlust`                - Show All available commands
- `/djlust settings`       - Open settings window
- `/djlust test`           - Test music & animation
- `/djlust stop`           - Stop music & animation
- `/djlust status`         - Shows current combat status and haste metrics.
- `/djlust reset`          - Manually reset haste baseline (automatically happens leaving/joining combat)
- `/djlust volume <0-100>` - Set volume (`/djlust volume 80` - set volume to 80%)
- `/djlust minimap`        - Toggle Minimap button on/off.
- `/djlust <lock|unlock>`  - Lock/Unlock Animation position.

<sub> [TIP] use `/djl` as alias for `/djlust` </sub>


---

**Known Limitations:**

- not exclusively checking bloodlust. <sub> we are only checking if our haste went up by 25% (can be manually configured in settings) in last 0.3 seconds. therefore spells like pres evoker tip of scales will trigger the music. This can be tweaked in djlust settings menu </sub>
- Droping Comabat and Rejoining Combat while lust is active will not restart the animation/music from displaying.
- Does **NOT** work outside of combat. 
- No localization framework (planned on or before v1.5.0)


<sub> Inspired by Pedro Lust Weakaura ❤️ </sub>
