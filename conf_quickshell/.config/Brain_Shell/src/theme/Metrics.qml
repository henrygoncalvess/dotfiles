pragma Singleton
import QtQuick

QtObject {
    // --Bar Toggle--
    property bool barEnabled: false

    // -- Bar Sizes --
    property int borderWidth:   0
    property int cornerRadius:  0
    property int notchRadius:   12
    property int notchHeight:   22
    property int exclusionGap:  22
    property int spacing:       0

    // -- Notch Content Padding --
    // Space added around the content inside each notch
    property int notchPadding:           0   // horizontal padding each side
    property int notchHorizontalPadding: 2
    property int notchVerticalPadding:   0
    property int notchSideMargin:        0

    // -- Notch Width Constraints --
    // Each notch sizes itself to its content, clamped between min and max.
    property int lNotchMinWidth: 180
    property int lNotchMaxWidth: 360

    property int cNotchMinWidth: 300
    property int cNotchMaxWidth: 360

    property int rNotchMinWidth: 180
    property int rNotchMaxWidth: 360

    // -- Dashboard Dimensions --
    // Target size the center notch expands to when the dashboard is open.
    property int dashboardWidth:  900
    property int dashboardHeight: 520

    // -- Notifications Popup Width --
    property int notificationsWidth: 400
    property int notificationToastWidth: notificationsWidth / 1.2
    property int networkPopupWidth:  480

    // -- Popup Size Constraints --
    property int popupMinWidth:   160
    property int popupMaxWidth:   420
    property int popupMinHeight:   80
    property int popupMaxHeight:  520
    property int popupPadding:     16

    // -- Workspace Dot Sizes --
    property int wsDotSize:     9
    property int wsActiveWidth: 26
    property int wsSpacing:     6
    property int wsPadding:     8
    property int wsRadius:      16

    // -- Animations --
    property int animDuration: 290
}
