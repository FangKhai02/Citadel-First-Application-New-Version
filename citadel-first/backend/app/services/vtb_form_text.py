"""Legal text constants for VTB KYC forms.

Each constant contains the EXACT text from the original VTB documents,
typed word-for-word. No paraphrasing or summarizing.

These are used by vtb_pdf_service.py to generate PDFs with full legal content.
"""

# ════════════════════════════════════════════════════════════════════════════════
# Form A1 — VTB Services Agreement
# ═════════════════════════════════════════════════════════════════════════════════

A1_TITLE = "VANGUARD TRUSTEE BERHAD\nSERVICES AGREEMENT"

A1_PREAMBLE = (
    "This Services Agreement is made on {date_of_trust_deed} between "
    "VANGUARD TRUSTEE BERHAD (Company No. 200401032157 (769486-W)) "
    "whose registered office is at Level 8, Menara MAA, 12, Jalan Meru, "
    "55100 Kuala Lumpur, Wilayah Persekutuan, Malaysia (hereinafter referred to as "
    '"the Trustee") and {name} (NRIC/Passport No.: {identity_card_number}) '
    "of {residential_address} (hereinafter referred to as \"the Client\")."
)

A1_SECTION_1_DEFINITIONS = """SECTION 1 — DEFINITIONS

1.1 In this Agreement, unless the context otherwise requires:

(a) "Business Day" means a day on which commercial banks are open for business in Malaysia;

(b) "Client" means the person named as the Client in this Agreement;

(c) "Trust Deed" means the trust deed establishing the Trust;

(d) "Trust" means the trust established pursuant to the Trust Deed;

(e) "Trustee" means Vanguard Trustee Berhad;

(f) "Trust Fund" means the trust fund established under the Trust Deed including all cash, assets and properties from time to time held by the Trustee upon the trusts thereof;

(g) "Trust Period" means the period commencing from the date of the Trust Deed and expiring on the date specified in the Trust Deed;

(h) "Beneficiary" means the person or persons for the time being entitled to benefit under the Trust;

(i) "Settlor" means the person who establishes the Trust; and

(j) "Fees" means the fees and charges as set out in Section 3 of this Agreement."""

A1_SECTION_2_SERVICES = """SECTION 2 — SERVICES

2.1 The Trustee shall provide the following services to the Client:

(a) to act as trustee of the Trust in accordance with the terms of the Trust Deed;

(b) to administer and manage the Trust Fund in accordance with the Trust Deed;

(c) to invest the Trust Fund in accordance with the investment direction given by the Client from time to time;

(d) to distribute the Trust Fund to the Beneficiaries in accordance with the Trust Deed;

(e) to maintain proper records and accounts of the Trust Fund;

(f) to provide periodic statements of account to the Client; and

(g) such other services as may be agreed between the Trustee and the Client from time to time.

2.2 The Trustee shall be entitled to engage such agents, professionals or other persons as the Trustee may in its absolute discretion deem necessary or desirable for the proper performance of its duties under this Agreement and the Trust Deed, and the costs of such engagement shall be borne by the Trust Fund.

2.3 The Trustee shall not be liable for any loss or damage suffered by the Client or any Beneficiary arising from any act or omission of any such agent, professional or other person engaged by the Trustee under Clause 2.2 unless such loss or damage is caused by the fraud, wilful default or negligence of the Trustee."""

A1_SECTION_3_FEES = """SECTION 3 — FEES AND DISBURSEMENTS

3.1 The Client agrees to pay to the Trustee the following fees:

(a) An initial setup fee as specified in the Schedule hereto;

(b) An annual trustee fee as specified in the Schedule hereto, payable in advance on the anniversary of the date of the Trust Deed;

(c) Such additional fees as may be agreed between the Trustee and the Client from time to time; and

(d) Goods and Services Tax (GST) or any applicable tax on the fees chargeable hereunder at the prevailing rate.

3.2 The Trustee shall be entitled to be reimbursed from the Trust Fund for all proper disbursements and expenses incurred by the Trustee in the performance of its duties under this Agreement and the Trust Deed.

3.3 The Trustee may deduct any fees and disbursements due under this Agreement from the Trust Fund without prior notice to the Client."""

A1_SECTION_4_POWER_OF_ATTORNEY = """SECTION 4 — POWER OF ATTORNEY

4.1 The Client hereby irrevocably appoints the Trustee as the Client's attorney to do all acts and things and execute all documents on behalf of the Client as the Trustee may consider necessary or desirable for the proper administration of the Trust.

4.2 The power of attorney granted under Clause 4.1 shall continue until the termination of this Agreement and the Trust."""

A1_SECTION_5_CONFIDENTIALITY = """SECTION 5 — CONFIDENTIALITY

5.1 The Trustee shall keep confidential all information relating to the Client and the Trust Fund and shall not disclose such information to any third party without the prior written consent of the Client except:

(a) as required by law or by any regulatory authority;

(b) to such agents, professionals or other persons engaged by the Trustee under Clause 2.2; or

(c) as may be necessary for the proper performance of the Trustee's duties under this Agreement and the Trust Deed.

5.2 The Client acknowledges that the Trustee may be required to disclose information relating to the Client and the Trust Fund to regulatory authorities under applicable laws and regulations, including but not limited to the Anti-Money Laundering, Anti-Terrorism Financing and Proceeds of Unlawful Activities Act 2001 and the Common Reporting Standard (CRS)."""

A1_SECTION_6_TERMINATION = """SECTION 6 — TERMINATION

6.1 This Agreement may be terminated by either party giving not less than thirty (30) days' written notice to the other party.

6.2 Upon termination of this Agreement:

(a) the Trustee shall deliver to the Client or as the Client may direct all documents, records and accounts relating to the Trust Fund;

(b) the Client shall pay to the Trustee all fees and disbursements due under this Agreement up to the date of termination; and

(c) the Trustee shall be discharged from all further obligations under this Agreement except for those obligations which by their nature survive termination.

6.3 Termination of this Agreement shall not affect any rights or obligations of either party which may have accrued before the date of termination."""

A1_SECTION_7_LIMITATION = """SECTION 7 — LIMITATION OF LIABILITY

7.1 The Trustee shall not be liable for any loss or damage suffered by the Client or any Beneficiary unless such loss or damage is caused by the fraud, wilful default or negligence of the Trustee.

7.2 In no event shall the Trustee be liable for any indirect, consequential or special loss or damage whatsoever.

7.3 The Trustee shall not be responsible for any loss arising from any investment of the Trust Fund made in accordance with the investment direction given by the Client."""

A1_SECTION_8_GENERAL = """SECTION 8 — GENERAL

8.1 This Agreement shall be governed by and construed in accordance with the laws of Malaysia.

8.2 Any dispute arising out of or in connection with this Agreement shall be submitted to the exclusive jurisdiction of the Malaysian courts.

8.3 No variation or modification of this Agreement shall be valid unless made in writing and signed by both parties.

8.4 This Agreement constitutes the entire agreement between the parties with respect to the subject matter hereof and supersedes all prior agreements and understandings relating thereto.

8.5 The Client shall not assign or transfer any of its rights or obligations under this Agreement without the prior written consent of the Trustee."""

A1_SIGNATURE_BLOCK = (
    "IN WITNESS WHEREOF the parties have executed this Agreement on the date first above written.\n\n"
    "_______________________________\n"
    "Signature of the Client\n"
    "{name}\n"
    "NRIC/Passport No.: {identity_card_number}\n\n\n"
    "_______________________________\n"
    "For and on behalf of\n"
    "VANGUARD TRUSTEE BERHAD\n"
    "Authorized Signatory"
)

# ════════════════════════════════════════════════════════════════════════════════
# Form A2 — VTB Risk Assessment Form
# ═════════════════════════════════════════════════════════════════════════════════

A2_TITLE = "VANGUARD TRUSTEE BERHAD\nRISK ASSESSMENT FORM"

A2_SECTION_A_PERSONAL = """PART A — PERSONAL PARTICULARS

Full Name: {name}
NRIC/Passport No.: {identity_card_number}
Date of Birth: {dob}
Nationality: {nationality}
Residential Address: {residential_address}
Mailing Address: {mailing_address}
Home Telephone: {home_telephone}
Mobile: {mobile_number}
Email: {email}
Occupation: {occupation}
Employer: {employer_name}
Annual Income Range: {annual_income_range}
Estimated Net Worth: {estimated_net_worth}"""

A2_SECTION_B_SOURCE_OF_FUNDS = """PART B — SOURCE OF FUNDS

Source of Trust Fund: {source_of_trust_fund}
Source of Income: {source_of_income}
Country of Birth: {country_of_birth}
Physically Present in Malaysia: {physically_present}"""

A2_SECTION_C_TAX_RESIDENCY = """PART C — TAX RESIDENCY / CRS SELF-CERTIFICATION

Please declare all jurisdictions in which you are a tax resident:

{crs_table}"""

A2_SECTION_D_ASSESSMENT = """PART D — RISK ASSESSMENT QUESTIONS

1. What are your main sources of income?
   {main_sources_of_income}

2. Have you been involved in any unusual or suspicious transactions?
   {has_unusual_transactions}

3. Please provide details of your marital history:
   {marital_history}

4. Do you have any geographical connections to high-risk jurisdictions?
   {geographical_connections}

5. Any other relevant information you wish to disclose?
   {other_relevant_info}"""

A2_SECTION_E_PEP = """PART E — POLITICALLY EXPOSED PERSON (PEP) DECLARATION

Are you a Politically Exposed Person (PEP)? {is_pep}
PEP Relationship: {pep_relationship}
PEP Name: {pep_name}
PEP Position: {pep_position}
PEP Organisation: {pep_organisation}"""

A2_DECLARATION = """DECLARATION

I, {name}, hereby declare that the information provided in this Risk Assessment Form is true and correct to the best of my knowledge and belief. I understand that any false or misleading information may result in the rejection of my application or the termination of any services provided by Vanguard Trustee Berhad.

I consent to Vanguard Trustee Berhad conducting such verification checks as may be necessary to confirm the information provided herein, including but not limited to checks with relevant authorities and financial institutions.

_______________________________
Signature of the Client
{name}
NRIC/Passport No.: {identity_card_number}
Date: {date_of_trust_deed}"""

# ════════════════════════════════════════════════════════════════════════════════
# Form B2 — Application for Trustee Service
# ═════════════════════════════════════════════════════════════════════════════════

B2_TITLE = "VANGUARD TRUSTEE BERHAD\nAPPLICATION FOR TRUSTEE SERVICE"

B2_SECTION_1_SETTLOR = """SECTION 1 — SETTLOR PARTICULARS

Title: {title}
Full Name: {name}
Gender: {gender}
Date of Birth: {dob}
Nationality: {nationality}
NRIC No.: {identity_card_number}
Passport No.: {passport_number}
Passport Expiry: {passport_expiry}
Marital Status: {marital_status}
Residential Address: {residential_address}
Mailing Address: {mailing_address}
Home Tel: {home_telephone}
Mobile: {mobile_number}
Email: {email}
Occupation: {occupation}
Work Title: {work_title}
Nature of Business: {nature_of_business}
Employer Name: {employer_name}
Employer Address: {employer_address}
Employer Tel: {employer_telephone}
Annual Income: {annual_income_range}
Estimated Net Worth: {estimated_net_worth}"""

B2_SECTION_2_TRUST = """SECTION 2 — TRUST DETAILS

Trust Name: CITADEL WEALTH DIVERSIFICATION TRUST
Trust Asset Amount: {trust_asset_amount}
Date of Trust Deed: {date_of_trust_deed}"""

B2_SECTION_3_BENEFICIARIES_HEADER_PRE = """SECTION 3 — BENEFICIARIES

3A. Pre-Demise Beneficiary(ies):"""

B2_SECTION_3_BENEFICIARIES_HEADER_POST = """3B. Post-Demise Beneficiary(ies):"""

B2_BENEFICIARY_ROW = (
    "Full Name: {full_name}\n"
    "NRIC/Passport No.: {nric}\n"
    "ID Number: {id_number}\n"
    "Gender: {gender}\n"
    "Date of Birth: {dob}\n"
    "Relationship to Settlor: {relationship_to_settlor}\n"
    "Residential Address: {residential_address}\n"
    "Mailing Address: {mailing_address}\n"
    "Email: {email}\n"
    "Contact Number: {contact_number}\n"
    "Bank Account Name: {bank_account_name}\n"
    "Bank Account Number: {bank_account_number}\n"
    "Bank Name: {bank_name}\n"
    "Bank SWIFT Code: {bank_swift_code}\n"
    "Bank Address: {bank_address}\n"
    "Share Percentage: {share_percentage}"
)

B2_DECLARATION = """DECLARATION

I, {name}, the Settlor named in this Application, hereby apply to Vanguard Trustee Berhad to act as Trustee for the trust described herein. I confirm that:

(a) The information provided in this Application is true and correct to the best of my knowledge and belief;

(b) I have read and understood the Terms and Conditions governing the Trust;

(c) The funds to be placed in the Trust are from legitimate sources and do not involve any money laundering, terrorist financing or other unlawful activities;

(d) I consent to Vanguard Trustee Berhad conducting such verification checks as may be necessary;

(e) I agree to provide such further information and documentation as may be required by Vanguard Trustee Berhad.

_______________________________
Signature of the Settlor
{name}
NRIC/Passport No.: {identity_card_number}
Date: {date_of_trust_deed}

_______________________________
For and on behalf of
VANGUARD TRUSTEE BERHAD
Authorized Signatory"""

# ════════════════════════════════════════════════════════════════════════════════
# Form B3 — Trust Deed (Individual)
# ═════════════════════════════════════════════════════════════════════════════════

B3_TITLE = "VANGUARD TRUSTEE BERHAD\nTRUST DEED (INDIVIDUAL)"

B3_PREAMBLE = (
    "THIS TRUST DEED is made on {date_of_trust_deed} between "
    "{name} (NRIC/Passport No.: {identity_card_number}) of {residential_address} "
    "(hereinafter referred to as \"the Settlor\") of the one part and "
    "VANGUARD TRUSTEE BERHAD (Company No. 200401032157 (769486-W)) whose registered "
    "office is at Level 8, Menara MAA, 12, Jalan Meru, 55100 Kuala Lumpur, Wilayah "
    "Persekutuan, Malaysia (hereinafter referred to as \"the Trustee\") of the other part."
)

B3_SECTION_1_TRUST = """1. TRUST NAME

The Trust established by this Deed shall be known as CITADEL WEALTH DIVERSIFICATION TRUST (\"the Trust\")."""

B3_SECTION_2_TRUST_FUND = """2. TRUST FUND

2.1 The Settlor hereby transfers to the Trustee the sum of {trust_asset_amount} (\"the Trust Fund\") to be held by the Trustee upon the trusts and with and subject to the powers and provisions hereinafter declared concerning the same.

2.2 The Trustee may accept additional contributions to the Trust Fund from the Settlor or any other person at any time during the Trust Period."""

B3_SECTION_3_TRUST_PERIOD = """3. TRUST PERIOD

3.1 The Trust shall commence on {date_of_trust_deed} and shall continue for the Trust Period as specified in the Schedule hereto unless terminated earlier in accordance with the provisions of this Deed.

3.2 Upon the expiry of the Trust Period, the Trustee shall distribute the Trust Fund to the Beneficiaries in accordance with Clause 4 hereof."""

B3_SECTION_4_BENEFICIARIES = """4. BENEFICIARIES

4.1 The Beneficiaries of the Trust shall be as specified in the Schedule hereto.

4.2 The Trustee shall distribute the Trust Fund to the Beneficiaries in accordance with the share percentages specified in the Schedule hereto."""

B3_SECTION_5_IRREVOCABILITY = """5. IRREVOCABILITY

5.1 The Settlor hereby declares that this Trust is irrevocable and the Settlor shall not be entitled to revoke, vary or amend the terms of this Trust Deed without the prior written consent of the Trustee.

5.2 Notwithstanding Clause 5.1, the Settlor may by written notice to the Trustee direct the Trustee to distribute the Trust Fund to the Beneficiaries in such manner as the Settlor may specify."""

B3_SECTION_6_AUTO_RENEWAL = """6. AUTO-RENEWAL

6.1 Subject to Clause 3.2, the Trust shall be automatically renewed for successive periods of one (1) year each (\"Renewal Period\") unless the Settlor gives written notice to the Trustee not less than thirty (30) days before the expiry of the then current Trust Period or any Renewal Period of the Settlor's intention not to renew the Trust.

6.2 Upon each renewal, the terms and conditions of this Trust Deed shall continue to apply."""

B3_SECTION_7_TRUSTEE_POWERS = """7. TRUSTEE POWERS

7.1 The Trustee shall have the following powers in addition to any powers conferred by law:

(a) to invest the Trust Fund in such investments as the Settlor may from time to time direct in writing;

(b) to hold the Trust Fund in the name of the Trustee or its nominee;

(c) to appoint agents, investment advisors and other professionals to assist in the administration of the Trust;

(d) to make such payments and distributions as are required under this Deed;

(e) to receive income and other benefits from the Trust Fund and to apply the same in accordance with this Deed;

(f) to execute all such documents and do all such acts as may be necessary or desirable for the proper administration of the Trust;

(g) to delegate any of its powers under this Clause to any person as the Trustee may deem fit; and

(h) to do all such other acts and things as may be necessary for or incidental to the exercise of any of the powers herein contained."""

B3_SECTION_8_APPLICABLE_LAW = """8. APPLICABLE LAW

8.1 This Deed shall be governed by and construed in accordance with the laws of Malaysia.

8.2 Any dispute arising out of or in connection with this Deed shall be submitted to the exclusive jurisdiction of the Malaysian courts."""

B3_EXECUTION = (
    "IN WITNESS WHEREOF the parties have executed this Deed on the date first above written.\n\n"
    "_______________________________\n"
    "Signature of the Settlor\n"
    "{name}\n"
    "NRIC/Passport No.: {identity_card_number}\n\n\n"
    "_______________________________\n"
    "For and on behalf of\n"
    "VANGUARD TRUSTEE BERHAD\n"
    "Authorized Signatory"
)

# ════════════════════════════════════════════════════════════════════════════════
# Form B4 — CRS Self-Certification Form
# ═════════════════════════════════════════════════════════════════════════════════

B4_TITLE = "COMMON REPORTING STANDARD (CRS)\nSELF-CERTIFICATION FORM\n(INDIVIDUAL)"

B4_INSTRUCTIONS = """IMPORTANT NOTES

This Self-Certification Form is required by Vanguard Trustee Berhad in order to comply with its obligations under the Common Reporting Standard (CRS) as adopted by Malaysia.

1. Please complete all sections of this form in full.

2. If you are a tax resident in more than one jurisdiction, please provide details for each jurisdiction in Section 2.

3. If you do not have a Taxpayer Identification Number (TIN) for a jurisdiction, please indicate the reason by selecting one of the following:
   Reason A — I am a resident of a jurisdiction that does not issue TINs to its residents
   Reason B — I am otherwise unable to obtain a TIN (please provide an explanation)
   Reason C — I am a resident of a jurisdiction that issues TINs to its residents but I have not been issued with a TIN

4. If any information provided in this form changes, you must notify Vanguard Trustee Berhad within 30 days of such change.

5. It is an offence to provide false or misleading information in this form."""

B4_SECTION_1_IDENTIFICATION = """SECTION 1 — IDENTIFICATION

Full Name: {name}
Residential Address: {residential_address}
Mailing Address: {mailing_address}"""

B4_SECTION_2_TAX_RESIDENCY = """SECTION 2 — TAX RESIDENCY

Please declare all jurisdictions in which you are a tax resident:

{crs_table}"""

B4_DECLARATION = """DECLARATION

I, {name}, hereby declare that:

(a) The information provided in this Self-Certification Form is true, correct and complete;

(b) I will notify Vanguard Trustee Berhad within 30 days of any change in circumstances that affects the tax residency information provided herein; and

(c) I authorise Vanguard Trustee Berhad to disclose the information provided herein to the Inland Revenue Board of Malaysia and to the tax authorities of any other jurisdiction as may be required under the CRS.

I understand that the information provided in this form may be reported to the tax authorities of my jurisdiction(s) of tax residence in accordance with the CRS.

_______________________________
Signature of the Account Holder
{name}
NRIC/Passport No.: {identity_card_number}
Date: {date_of_trust_deed}"""

# ════════════════════════════════════════════════════════════════════════════════
# Form B6 — Asset Allocation Direction Form
# ═════════════════════════════════════════════════════════════════════════════════

B6_TITLE = "VANGUARD TRUSTEE BERHAD\nASSET ALLOCATION DIRECTION FORM"

B6_BODY = (
    "I, {name} (NRIC/Passport No.: {identity_card_number}), the Settlor of "
    "CITADEL WEALTH DIVERSIFICATION TRUST, hereby direct Vanguard Trustee Berhad, "
    "as Trustee of the said Trust, to accept the trust asset in the amount of "
    "{trust_asset_amount} as at {date_of_trust_deed}."
)

B6_ADVISOR = "Financial Advisor: {advisor_name} (NRIC: {advisor_nric})"

B6_DECLARATION = (
    "I hereby confirm that the above direction is given voluntarily and that I have "
    "read and understood the terms and conditions of the Trust Deed. I acknowledge "
    "that the Trustee shall be entitled to rely on this direction without further "
    "verification and shall not be liable for any loss arising from its reliance on "
    "this direction."
)

B6_SIGNATURE = (
    "_______________________________\n"
    "Signature of the Settlor\n"
    "{name}\n"
    "NRIC/Passport No.: {identity_card_number}\n"
    "Date: {date_of_trust_deed}\n\n\n"
    "_______________________________\n"
    "For and on behalf of\n"
    "VANGUARD TRUSTEE BERHAD\n"
    "Authorized Signatory"
)