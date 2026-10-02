/// Static configuration for the Nexora platform.
library;

const kAppName = 'Nexora - Next Era';

/// Developer and Super Admin emails.
/// Accounts matching this list (or the very first member registered)
/// are automatically verified with Super Admin privileges.
const kDeveloperEmails = <String>[
  'gokultn592@gmail.com',
];

/// Configurable nexus settings, allowing environment-level overrides.
class NexusConfig {
  static String url = kNexusUrl;
}

/// Base URL of the Nexus Progressive Web App rendered inside the Nexus tab.
const kNexusUrl = 'https://nexus-e7a36.web.app/index.html';

/// Roles a verified Nexora account can hold.
///
/// Note: `'candidate'` is intentionally absent. `AuthGate` and `PendingScreen`
/// used to test `role != 'candidate'` as a proxy for "approved", but no code
/// path ever wrote that value, so *any* non-empty role passed the gate.
const kRoleStudent = 'student';
const kRoleAdmin = 'admin';
const kRoleSuperAdmin = 'superadmin';

/// Maximum number of courses a student can enrol in.
///
/// ProfileSetup historically allowed 12 while ProfileEdit rendered 7 and wrote
/// all 7 back on save, silently dropping courses 8-12. Both screens now derive
/// their limit from this single value.
const kMaxCourses = 12;

const kFaculties = <String>[
  'Computing',
  'Engineering',
  'Business',
  'Science',
  'Health Sciences',
  'Arts & Humanities',
];

/// Default student community branches (can be extended or altered by admins).
const kCommunityBranches = <String>[
  'Int MTech DS',
  'Int MTech CSE',
  'Int MTech SE',
];

/// Academic department options shown in the profile department dropdown.
const kDepartments = <String>[
  'Int MTech DS',
  'Int MTech CSE',
  'Int MTech SE',
  'B.Tech CSE',
  'B.Tech ECE',
  'B.Tech EEE',
  'B.Tech Mech',
  'B.Tech Civil',
  'B.Tech IT',
  'B.Tech AIDS',
  'B.Tech AIML',
  'MCA',
  'MBA',
  'Other',
];

/// Academic year options (numeric string) for the year dropdown.
const kAcademicYears = <String>['1', '2', '3', '4', '5'];

/// Default course names for student enrollment dropdown.
/// Admins can dynamically alter this list via the Admin Portal.
const kDefaultCourseNames = <String>[
  'Operating Systems Fundamentals',
  'Computer Architecture and Organization',
  'Database System Design',
  'Design and Analysis of Algorithms',
  'Applied Linear Algebra',
  'Qualitative and Quantitative skills',
  'Humanities',
];

/// Known default metadata for the initial course catalog.
/// Used to autofill faculty and slot suggestions when a course is chosen.
const kDefaultCourseMetadata = <String, Map<String, String>>{
  'Operating Systems Fundamentals': {
    'code': '',
    'faculty': '',
    'slot': 'E1 + TE1',
  },
  'Computer Architecture and Organization': {
    'code': '',
    'faculty': 'Sivakumar',
    'slot': 'A1 + TA1 + TAA1',
  },
  'Database System Design': {
    'code': '',
    'faculty': 'Murali',
    'slot': 'D1 + TD1',
  },
  'Design and Analysis of Algorithms': {
    'code': '',
    'faculty': 'Nalliah',
    'slot': 'F1 + TF1',
  },
  'Applied Linear Algebra': {
    'code': '',
    'faculty': 'Ragukumar',
    'slot': 'C1 + TC1 + TCC1',
  },
  'Qualitative and Quantitative skills': {
    'code': '',
    'faculty': 'Arivu',
    'slot': 'G1 + TG1',
  },
  'Humanities': {
    'code': '',
    'faculty': 'Abhijit Dasgupta',
    'slot': 'B1 + TB1',
  },
  'Extracurricular activities': {
    'code': '',
    'faculty': 'Naiju',
    'slot': '',
  },
};

const kSlots = <String>[
  'Morning',
  'Evening',
];


/// Signature colours an approving officer is stamped with.
const kApproverPalette = <String>[
  '#3B82F6', // Verified Blue
  '#30A46C', // Emerald Green
  '#F5A524', // Amber Gold
  '#E5484D', // Crimson Red
  '#B084F7', // Electric Purple
  '#2DD4BF', // Teal Cyan
];

const kStorageNotesFolder = 'notes';
const kStorageProfileFolder = 'profile_pics';

const kMaxNoteImageBytes = 6 * 1024 * 1024;
const kMaxProfileImageBytes = 4 * 1024 * 1024;
