/// Dropdown option constants for the post-eKYC information capture pages.
library;

// ── Title ──
const kTitleOptions = [
  'Mr',
  'Mrs',
  'Ms / Miss',
  'Mdm',
  'Dr',
  'Dato',
  'Datin',
  'Tan Sri',
  'Puan Sri',
];

// ── Marital Status ──
const kMaritalStatusOptions = [
  'Single',
  'Married',
  'Divorced',
  'Widowed',
  'Separated',
];

// ── Employment Type ──
const kEmploymentTypeOptions = [
  'Employed',
  'Self-Employed',
  'Retired',
  'Housewife',
  'Unemployed',
  'Student',
];

// ── Occupation ──
const kOccupationOptions = [
  'Accountant',
  'Architect',
  'Business Owner',
  'Civil Servant',
  'Consultant',
  'Doctor',
  'Engineer',
  'Executive',
  'Financial Analyst',
  'Lawyer',
  'Manager',
  'Military/Police',
  'Nurse',
  'Pharmacist',
  'Real Estate Agent',
  'Teacher',
  'Technician',
  'Trader',
  'Other',
];

// ── Nature of Business ──
const kNatureOfBusinessOptions = [
  'Agriculture',
  'Construction',
  'Education',
  'Financial Services',
  'Government',
  'Healthcare',
  'Hospitality & Tourism',
  'IT/Technology',
  'Legal',
  'Manufacturing',
  'Mining',
  'Oil & Gas',
  'Real Estate',
  'Retail',
  'Telecommunications',
  'Transportation',
  'Wholesale & Distribution',
  'Other',
];

// ── Source of Trust Fund ──
const kSourceOfFundOptions = [
  'Salary',
  'Investment Income',
  'Personal Savings',
  'Family Contribution',
  'Others',
];

// ── Source of Income (dropdown) ──
const kSourceOfIncomeOptions = [
  'Employment',
  'Business',
  'Investment',
  'Inheritance',
  'Gift',
  'Rental Income',
  'Others',
];

// ── CRS No TIN Reason ──
const kCrsNoTinReasons = {
  'A': 'A — I have not been issued a TIN by the relevant jurisdiction',
  'B': 'B — I am unable to obtain a TIN for reasons stated below',
  'C': 'C — The jurisdiction does not issue TINs to its residents',
};

// ── PEP Relationship ──
const kPepRelationshipOptions = [
  'Self',
  'Immediate Family Member',
  'Close Associate',
];

// ── Employment types that hide employer fields ──
const kEmploymentTypesWithoutEmployer = {'Retired', 'Housewife', 'Unemployed', 'Student'};