import Foundation

/// Which language they speak. Chosen in the menu, not inherited from the
/// system: someone running a Mac in English may well want an Arabic parrot.
enum Language: String, CaseIterable {
    case english = "en"
    case arabic = "ar"

    /// Named in its own language, as language pickers should be.
    var title: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية (السعودية)"
        }
    }

    var isRightToLeft: Bool { self == .arabic }
}

/// Menu and dialog text.
///
/// A plain table rather than `.lproj` bundles, because the language is an
/// in-app setting: `NSLocalizedString` would follow the system language and
/// ignore the menu entirely.
enum UI {
    static func t(_ key: String, _ language: Language) -> String {
        if language == .english { return key }
        return arabic[key] ?? key
    }

    private static let arabic: [String: String] = [
        // Actions
        "Say Hello": "قل مرحبًا",
        "Do Something": "اعمل شيئًا",
        "Tell a Joke": "احكِ نكتة",
        "Tell Me Something": "معلومة من فضلك",
        "Sing a Song": "غنِّ أغنية",
        "Let Them Chat": "دعهما يتحدثان",
        "Say Something": "قل شيئًا",
        "Let Them Talk": "دعهم يتحدثون",
        "Let Them Fight": "دعهم يتقاتلون",
        "Liveliness": "النشاط",
        "Calm": "هادئ",
        "Restless": "كثير الحركة",
        "More": "المزيد",
        "Do a Trick": "استعرض شيئًا",
        "Ask Me a Riddle": "اسألني لغزًا",
        "Tongue Twister": "عبارة صعبة",
        "Come Here": "تعال هنا",
        "Send Away": "اذهب الآن",

        // Settings
        "Who's Here": "من الحاضر",
        "Voice": "الصوت",
        "Pitch": "طبقة الصوت",
        "Chattiness": "كثرة الكلام",
        "Size": "الحجم",
        "Language": "اللغة",
        "Mute Voices": "كتم الأصوات",
        "Mute Sounds": "كتم المؤثرات",
        "Unmute Sounds": "إلغاء كتم المؤثرات",
        "Unmute Voices": "إلغاء كتم الأصوات",
        "Open at Login": "التشغيل عند بدء الجلسة",
        "About": "عن التطبيق",
        "Quit": "إنهاء",

        // Levels
        "Quiet": "هادئ",
        "Occasional": "معتدل",
        "Chatty": "كثير الكلام",
        "Small": "صغير",
        "Medium": "متوسط",
        "Large": "كبير",
        "Deep": "عميق",
        "Low": "منخفض",
        "High": "مرتفع",
        "Squeaky": "حاد",

        // Dialogs
        "Desktop Buddies": "رفاق سطح المكتب",
        "About body": """
            بيدي ببغاء، وبونزي غوريلا. يتمشون على سطح مكتبك، ويسوّون شوي \
            فقرات، ويتجادلون أحيانًا. خذ واحد منهم أو الاثنين.

            ما يتصلون بالإنترنت، ولا يجمعون أي بيانات، ولا يغيّرون متصفحك، \
            وما عندهم شي يبيعونه لك. عندهم مستوى صوت خاص فيهم، مستقل عن صوت \
            النظام — وتقدر تكتمهم أو تنهيهم من هالقائمة في أي وقت.

            يتكلمون باللهجة النجدية. الصوت المتوفر في ماك عربي فصيح، فالنطق \
            فصيح واللهجة سعودية.

            الرسوم من مجموعة شخصيات Microsoft Agent.
            """,
        "OK": "حسنًا",
        "Nobody could be found.": "لم يتم العثور على أحد.",
        "Missing resources": "ملفات الشخصيات غير موجودة في حزمة التطبيق.",
        "Add them under Login Items": "أضفهما إلى عناصر بدء التشغيل",
        "Login items body": """
            في macOS 12 وما قبله، يُضبط هذا من تفضيلات النظام ← المستخدمون \
            والمجموعات ← عناصر بدء التشغيل.
            """,
        "Open Login Items": "فتح عناصر بدء التشغيل",
        "Cancel": "إلغاء",
        "Couldn't change the login setting.": "تعذّر تغيير إعداد بدء التشغيل.",
        "Login error hint": "عادةً ما يتطلب هذا وجود التطبيق في مجلد التطبيقات وأن يكون موقّعًا.",
        "voice preview": "مرحبًا. اسمي",
        "pitch preview": "كيف يبدو هذا الصوت؟",
    ]
}
