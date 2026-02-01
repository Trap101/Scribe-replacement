import 'package:uuid/uuid.dart';
import 'form_field_model.dart';
import 'report_model.dart';

class ReportTemplate {
  static final _uuid = Uuid();

  static ParamedicReport createBlankReport() {
    return ParamedicReport(
      reportId: _uuid.v4(),
      createdAt: DateTime.now(),
      sections: [
        _incidentAndDispatch(),
        _patientDetails(),
        _chiefComplaintAndHistory(),
        _primarySurvey(),
        _observationsAndVitals(),
        _fastAndCardiac(),
        _airwayManagement(),
        _resuscitation(),
        _treatmentAndDrugs(),
        _injuryAndTrauma(),
        _patientManagement(),
        _dispositionAndOutcome(),
      ],
    );
  }

  // ── 1. Incident & Dispatch ──────────────────────────────────────────
  static FormSection _incidentAndDispatch() {
    return FormSection(
      id: 'incident_dispatch',
      title: 'Incident & Dispatch',
      fields: [
        // Incident
        FormFieldModel(id: 'transportRequestIncidentNumber', label: 'Transport Request Incident Number', type: FieldType.text),
        FormFieldModel(id: 'incidentTime', label: 'Time of incident', type: FieldType.time),
        FormFieldModel(id: 'incidentDate', label: 'Date of incident', type: FieldType.date),
        FormFieldModel(id: 'reportedCondition', label: 'Reported clinical condition', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'transportRequestCallConnectTime', label: 'Call Connect time', type: FieldType.time),
        FormFieldModel(id: 'transportRequestCallType', label: 'Category of initial call for help', type: FieldType.dropdown, options: ['Called GP who saw patient before calling EMS', 'Called GP who called EMS before seeing patient', 'Called 999', 'Called NHS Direct', 'Called Local Helpline', 'Called GP and told to make own way to hospital', 'Called GP who told patient to call EMS', 'Resuscitation attempted or ceased', 'Not Known']),
        FormFieldModel(id: 'timeLeftScene', label: 'Time crew left the scene', type: FieldType.time),
        // Dispatch
        FormFieldModel(id: 'dispatchTime', label: 'Dispatch notification time', type: FieldType.time),
        FormFieldModel(id: 'ambulanceArrivalTime', label: 'Ambulance arrival time at destination', type: FieldType.time),
        FormFieldModel(id: 'responseMobileTime', label: 'Response vehicle mobile time', type: FieldType.time),
        // GPS Coordinates
        FormFieldModel(id: 'latitude', label: 'Latitude', type: FieldType.text),
        FormFieldModel(id: 'longitude', label: 'Longitude', type: FieldType.text),
        // Priority Assessment
        FormFieldModel(id: 'conditionCatagory', label: 'Condition category (EMD protocols)', type: FieldType.number),
        FormFieldModel(id: 'urgencyCatagory', label: 'Urgency category', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'postDispatchInstructions', label: 'Post-dispatch instructions from EMD', type: FieldType.text),
      ],
    );
  }

  // ── 2. Patient Details ──────────────────────────────────────────────
  static FormSection _patientDetails() {
    return FormSection(
      id: 'patient_details',
      title: 'Patient Details',
      fields: [
        // Patient
        FormFieldModel(id: 'patientIdentifier', label: 'Patient unique identifier', type: FieldType.text),
        // Patient Details
        FormFieldModel(id: 'NHSNumber', label: 'Patient NHS Number', type: FieldType.number),
        FormFieldModel(id: 'age', label: 'Age of patient', type: FieldType.number),
        FormFieldModel(id: 'dateOfBirth', label: 'Date of Birth (ccyy-mm-dd)', type: FieldType.text),
        FormFieldModel(id: 'familyName', label: 'Surname', type: FieldType.text),
        FormFieldModel(id: 'givenName', label: 'Forename', type: FieldType.text),
        FormFieldModel(id: 'patientDetails_title', label: 'Person Title', type: FieldType.text),
        FormFieldModel(id: 'ethnicGroup', label: 'Ethnic Group', type: FieldType.dropdown, options: ['British', 'Irish', 'Any other White background', 'White and Black Caribbean', 'White and Black African', 'White and Asian', 'Any other mixed background', 'Indian', 'Pakistani', 'Bangladeshi', 'Any other Asian background', 'Caribbean', 'African', 'Any other Black background', 'Chinese', 'Any other ethnic group', 'Not stated']),
        FormFieldModel(id: 'religiousAffiliation', label: 'Religious or Belief Affiliation', type: FieldType.text),
        FormFieldModel(id: 'sexualOrientation', label: 'Sexual Orientation', type: FieldType.dropdown, options: ['Heterosexual', 'Homosexual', 'Bi-sexual', 'Does not know/unsure', 'Not Stated']),
        FormFieldModel(id: 'sex', label: 'Sex', type: FieldType.dropdown, options: ['Not Known', 'Male', 'Female', 'Not Specified/Indeterminate']),
        // Structured Address
        FormFieldModel(id: 'addressPrefix', label: 'Address Prefix (e.g. Ward 12)', type: FieldType.text),
        FormFieldModel(id: 'buildingName', label: 'Building Name', type: FieldType.text),
        FormFieldModel(id: 'buildingNumber', label: 'Building Number', type: FieldType.text),
        FormFieldModel(id: 'dependentLocality', label: 'Dependent Locality', type: FieldType.text),
        FormFieldModel(id: 'dependentStreet', label: 'Dependent Street or Road Name', type: FieldType.text),
        FormFieldModel(id: 'doubleDependentLocality', label: 'Double Dependent Locality', type: FieldType.text),
        FormFieldModel(id: 'postalCounty', label: 'Postal County', type: FieldType.text),
        FormFieldModel(id: 'postTown', label: 'Post Town', type: FieldType.text),
        FormFieldModel(id: 'streetOrRoadName', label: 'Street or Road Name', type: FieldType.text),
        FormFieldModel(id: 'postcode', label: 'Postcode', type: FieldType.text),
        // Unstructured Address
        FormFieldModel(id: 'addressLine1', label: 'Address Line 1', type: FieldType.text),
        FormFieldModel(id: 'addressLine2', label: 'Address Line 2', type: FieldType.text),
        FormFieldModel(id: 'addressLine3', label: 'Address Line 3', type: FieldType.text),
        FormFieldModel(id: 'addressLine4', label: 'Address Line 4', type: FieldType.text),
        FormFieldModel(id: 'addressLine5', label: 'Address Line 5', type: FieldType.text),
      ],
    );
  }

  // ── 3. Chief Complaint & History ────────────────────────────────────
  static FormSection _chiefComplaintAndHistory() {
    return FormSection(
      id: 'chief_complaint_history',
      title: 'Chief Complaint & History',
      fields: [
        // Chief Complaint
        FormFieldModel(id: 'presentingComplaint', label: 'Primary patient problem identified', type: FieldType.dropdown, options: ['Cerebral', 'Respiratory', 'Cardiac', 'Abdominal', 'Endocrine', 'Obstetrics', 'Miscellaneous (including psychiatric)', 'Trauma: Mechanical', 'Trauma: NonMechanical']),
        FormFieldModel(id: 'assessmentTime', label: 'Time of assessment', type: FieldType.time),
        FormFieldModel(id: 'additionalInformation', label: 'Additional information (medic alert etc.)', type: FieldType.text),
        FormFieldModel(id: 'pastMedicalHistory', label: 'Past medical history', type: FieldType.text),
        FormFieldModel(id: 'socialAndFamiliyHistory', label: 'Family and social history', type: FieldType.text),
        // Current Medication
        FormFieldModel(id: 'currentMedication_name', label: 'Current medication name', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'currentMedication_dosage', label: 'Medication dosage', type: FieldType.number),
        FormFieldModel(id: 'currentMedication_frequency', label: 'Medication frequency', type: FieldType.number),
        FormFieldModel(id: 'currentMedication_compliance', label: 'Medication compliance', type: FieldType.dropdown, options: ['Yes', 'No', 'Unknown']),
        FormFieldModel(id: 'currentMedication_comments', label: 'Medication comments', type: FieldType.text),
        // Known Allergy
        FormFieldModel(id: 'knownAllergy_type', label: 'Patient allergy', type: FieldType.dropdown, options: []),
        // Symptom
        FormFieldModel(id: 'symptomType', label: 'Symptom type', type: FieldType.dropdown, options: []),
      ],
    );
  }

  // ── 4. Primary Survey ───────────────────────────────────────────────
  static FormSection _primarySurvey() {
    return FormSection(
      id: 'primary_survey',
      title: 'Primary Survey',
      fields: [
        // AVPU Assessment
        FormFieldModel(id: 'AVPUScale', label: 'Consciousness Assessment (AVPU)', type: FieldType.dropdown, options: ['Alert', 'Voice', 'Pain', 'Unresponsive']),
        // Airway Assessment
        FormFieldModel(id: 'airwayStatus', label: 'Airway status', type: FieldType.dropdown, options: ['Clear', 'Obstructed - Food', 'Obstructed - Foreign Object', 'Obstructed - Tongue', 'Part. Obstructed - Food', 'Part. Obstructed - Foreign Object', 'Part. Obstructed - Tongue', 'Part. Obstructed - Blood', 'Vomit in airway', 'Tracheostomy: Clear', 'Tracheostomy: Blocked']),
        FormFieldModel(id: 'selfMaintain', label: 'Ability to maintain airway', type: FieldType.dropdown, options: ['Normal', 'Maintainable', 'Not Maintainable']),
        // Breathing Assessment
        FormFieldModel(id: 'respiratoryRate', label: 'Respiratory rate assessment', type: FieldType.dropdown, options: ['Fast', 'Normal', 'Slow']),
        FormFieldModel(id: 'respiratorySigns', label: 'Respiratory signs', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'respiratoryEffort', label: 'Respiratory effort', type: FieldType.dropdown, options: ['Shallow', 'Normal', 'Retractive']),
        FormFieldModel(id: 'respiratoryDepth', label: 'Respiratory depth', type: FieldType.dropdown, options: []),
        // Circulatory Assessment
        FormFieldModel(id: 'pulseSite', label: 'Pulse site', type: FieldType.dropdown, options: ['Left Radial', 'Left Brachial', 'Left Carotid', 'Left Femoral', 'Right Radial', 'Right Brachial', 'Right Carotid', 'Right Femoral', 'Other']),
        FormFieldModel(id: 'pulseRate', label: 'Pulse rate', type: FieldType.dropdown, options: ['Normal', 'Rapid', 'Slow', 'Absent', 'Other']),
        FormFieldModel(id: 'pulseRhythm', label: 'Pulse rhythm', type: FieldType.dropdown, options: ['Regular', 'Irregular', 'Other']),
        FormFieldModel(id: 'pulseStrength', label: 'Pulse strength', type: FieldType.dropdown, options: ['Strong', 'Weak', 'Bounding', 'Absent', 'Other']),
        FormFieldModel(id: 'capillaryRefill', label: 'Capillary refill', type: FieldType.dropdown, options: ['Less than 2 seconds', 'More than 2 seconds']),
        // Skin Assessment
        FormFieldModel(id: 'skinColour', label: 'Skin colour observation', type: FieldType.dropdown, options: ['Normal', 'Cyanosed', 'Flushed', 'Jaundice', 'Mottling', 'Pallor (decrease in colour)', 'Rash', 'Other']),
        FormFieldModel(id: 'skinTemperature', label: 'Skin temperature', type: FieldType.dropdown, options: ['Normal', 'Warm', 'Cool', 'Hot', 'Cold', 'Other']),
        FormFieldModel(id: 'skinLocation', label: 'Skin observation body location', type: FieldType.dropdown, options: []),
      ],
    );
  }

  // ── 5. Observations & Vitals ────────────────────────────────────────
  static FormSection _observationsAndVitals() {
    return FormSection(
      id: 'observations_vitals',
      title: 'Observations & Vitals',
      fields: [
        // Blood Pressure
        FormFieldModel(id: 'systolicBP', label: 'Systolic blood pressure', type: FieldType.number),
        FormFieldModel(id: 'diastolicBP', label: 'Diastolic blood pressure', type: FieldType.number),
        // Blood Glucose
        FormFieldModel(id: 'bloodGlucose', label: 'Blood glucose (mmol/L or mg/dL)', type: FieldType.number),
        // Body Temperature
        FormFieldModel(id: 'bodyTemperature_value', label: 'Body temperature reading', type: FieldType.number),
        FormFieldModel(id: 'bodyTemperature_site', label: 'Temperature measurement site', type: FieldType.number),
        // Pulse Oximetry
        FormFieldModel(id: 'SpO2Reading', label: 'Oxygen saturation (SpO2)', type: FieldType.number),
        // Respiratory Resistance
        FormFieldModel(id: 'peakFlowReading', label: 'Peak flow reading (ltrs/min)', type: FieldType.number),
        // Pain Assessment
        FormFieldModel(id: 'painScore', label: 'Pain score (0-10)', type: FieldType.number),
        FormFieldModel(id: 'painLocation', label: 'Pain location', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'painNature', label: 'Nature of pain', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'painDuration', label: 'Duration of pain', type: FieldType.dropdown, options: []),
        // Glasgow Coma Scale
        FormFieldModel(id: 'GCSItem', label: 'GCS item score (Eyes/Motor/Verbal)', type: FieldType.number),
        FormFieldModel(id: 'GCSScore', label: 'GCS individual score', type: FieldType.number),
        FormFieldModel(id: 'GCSTotal', label: 'GCS total score', type: FieldType.number),
        // Pupil Assessment
        FormFieldModel(id: 'pupilEye', label: 'Eye being assessed', type: FieldType.dropdown, options: ['Left', 'Right']),
        FormFieldModel(id: 'pupilDilation', label: 'Pupil dilation', type: FieldType.number),
        FormFieldModel(id: 'pupilReaction', label: 'Pupil reaction', type: FieldType.dropdown, options: ['Brisk', 'Sluggish', 'Fixed']),
        FormFieldModel(id: 'pupilEquality', label: 'Pupil equality', type: FieldType.dropdown, options: ['Normal', 'Constricted', 'Dilated', 'Blind', 'Cataract', 'Contact Lenses', 'Glass Eye']),
      ],
    );
  }

  // ── 6. FAST & Cardiac ──────────────────────────────────────────────
  static FormSection _fastAndCardiac() {
    return FormSection(
      id: 'fast_cardiac',
      title: 'FAST & Cardiac',
      fields: [
        // FAST Assessment
        FormFieldModel(id: 'fastFace', label: 'FAST - Face weakness', type: FieldType.dropdown, options: ['Abnormal', 'Normal']),
        FormFieldModel(id: 'fastArm', label: 'FAST - Arm motor weakness', type: FieldType.dropdown, options: ['Abnormal', 'Normal']),
        FormFieldModel(id: 'fastSpeech', label: 'FAST - Speech', type: FieldType.dropdown, options: ['Abnormal', 'Normal']),
        FormFieldModel(id: 'fastConclusion', label: 'FAST conclusion', type: FieldType.dropdown, options: ['Negative', 'Non-conclusive', 'Positive', 'Not Available']),
        // Cardiac
        FormFieldModel(id: 'chestPainOnsetDate', label: 'Chest pain onset date', type: FieldType.date),
        FormFieldModel(id: 'chestPainOnsetTime', label: 'Chest pain onset time', type: FieldType.time),
        FormFieldModel(id: 'cardiacArrest', label: 'Cardiac arrest', type: FieldType.dropdown, options: ['No', 'Yes Prior to 999 Arrival', 'Yes After 999 Arrival']),
        FormFieldModel(id: 'estimatedArrestTime', label: 'Estimated time of arrest', type: FieldType.dropdown, options: ['0-2 mins', '2-4 mins', '4-6 mins', '6-8 mins', '8-10 mins', '10-15 mins', '15-20 mins', '20 minutes', 'Not Available', 'Not Known', 'Other']),
        FormFieldModel(id: 'witness', label: 'Arrest witnessed by', type: FieldType.dropdown, options: ['Witnessed by Ambulance Clinicians', 'Witnessed by Community Responders', 'Bystander Witness', 'Not Witnessed', 'Other']),
        // ECG Interpretation
        FormFieldModel(id: 'ecgRhythm', label: 'ECG rhythm', type: FieldType.dropdown, options: ['Sinus rhythm', 'Sinus Arrhythmia', 'Sinus bradycardia', 'Sinus Tachycardia', 'Supraventricular Tachycardia (SVT)', 'PSVT', 'Atrial Fibrillation (A-Fib)', 'Atrial Flutter (A-Flutter)', '1 Degree Block', '2 Degree Block Type I', '2 Degree Block Type II', '3 Degree Block', 'Junctional Escape', 'Accelerated Junctional', 'Junctional Tachycardia', 'Ventricular Escape', 'Ventricular Fibrillation (V-Fib)', 'Ventricular Tachycardia (V-Tach)', 'Run of V-Tach', 'Asystole', 'Pacemaker', 'Other']),
        FormFieldModel(id: 'ecgEctopy', label: 'ECG ectopy', type: FieldType.dropdown, options: ['PVCs unifocal', 'PVCs-multifocal', 'PACS', 'PJCS', 'Other']),
        FormFieldModel(id: 'ecgLeadType', label: 'ECG lead type', type: FieldType.dropdown, options: ['3', '12', '15', '18']),
        FormFieldModel(id: 'ecgAbnormality', label: 'ECG abnormality', type: FieldType.dropdown, options: ['Non-Diagnostic', 'ST Elevation', 'MI - Inferior', 'MI - Anterior', 'LBBB', 'RBBB', 'MI - Lateral', 'ST Depression', 'T Wave Inversion', 'MI - Posterior', 'Other']),
        FormFieldModel(id: 'ecgInterpretationTime', label: 'ECG interpretation time', type: FieldType.time),
      ],
    );
  }

  // ── 7. Airway Management ───────────────────────────────────────────
  static FormSection _airwayManagement() {
    return FormSection(
      id: 'airway_management',
      title: 'Airway Management',
      fields: [
        // Airway Adjunct
        FormFieldModel(id: 'airwayAdjunct_type', label: 'Airway adjunct type', type: FieldType.dropdown, options: ['Oropharangeal (OP) Airway', 'Nasopharyngeal (NP) Airway', 'Other']),
        FormFieldModel(id: 'airwayAdjunct_outcome', label: 'Airway adjunct outcome', type: FieldType.text),
        // Intubation
        FormFieldModel(id: 'intubation_type', label: 'Intubation type', type: FieldType.dropdown, options: ['Endotracheal (ET)', 'Oesophageal tracheal combitube (OTC)', 'LMA', 'Other']),
        FormFieldModel(id: 'intubation_technique', label: 'Intubation technique', type: FieldType.dropdown, options: ['Standard laryngoscopy', 'Bougie', 'Digital', 'Medication facilitated', 'Bougie and Medication facilitated', 'Other']),
        FormFieldModel(id: 'intubation_outcome', label: 'Intubation outcome', type: FieldType.text),
        // Suction
        FormFieldModel(id: 'suction_contentsObserved', label: 'Suction contents observed', type: FieldType.text),
        FormFieldModel(id: 'suction_catheterType', label: 'Suction catheter type', type: FieldType.dropdown, options: ['Soft', 'Rigid']),
        FormFieldModel(id: 'suction_totalAttempts', label: 'Suction total attempts', type: FieldType.number),
        FormFieldModel(id: 'suction_method', label: 'Suction method', type: FieldType.dropdown, options: ['Oral', 'Nasal', 'Other']),
        // Suction Attempt
        FormFieldModel(id: 'suctionAttempt_number', label: 'Suction attempt number', type: FieldType.number),
        FormFieldModel(id: 'suctionAttempt_outcome', label: 'Suction attempt outcome', type: FieldType.dropdown, options: ['Successful', 'Unsuccessful']),
        FormFieldModel(id: 'suctionAttempt_response', label: 'Patient response to suction', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'suctionAttempt_complication', label: 'Suction complication', type: FieldType.dropdown, options: []),
        // Ventilation
        FormFieldModel(id: 'ventilation_method', label: 'Ventilation method', type: FieldType.dropdown, options: ['Manual', 'Mechanical', 'Other']),
        // Respiratory Support
        FormFieldModel(id: 'respiratorySupport_type', label: 'Respiratory support type', type: FieldType.dropdown, options: ['Not specified', 'Breathing Mask', 'Mouth-to-mouth', 'Endotracheal Intubation', 'Laryngeal Mask', 'Other']),
        FormFieldModel(id: 'respiratorySupport_outcome', label: 'Respiratory support outcome', type: FieldType.text),
        // Oxygen Administration
        FormFieldModel(id: 'oxygenFlowRate', label: 'Oxygen flow rate (l/min)', type: FieldType.number),
        FormFieldModel(id: 'oxygenAdministration_type', label: 'Oxygen delivery method', type: FieldType.dropdown, options: ['Nasal cannula', 'Non-rebreather', 'Venturi', 'BVM', 'Other']),
      ],
    );
  }

  // ── 8. Resuscitation ───────────────────────────────────────────────
  static FormSection _resuscitation() {
    return FormSection(
      id: 'resuscitation',
      title: 'Resuscitation',
      fields: [
        // CPR
        FormFieldModel(id: 'resuscitationAttempted', label: 'Resuscitation attempted', type: FieldType.dropdown, options: ['Resuscitation Attempted - Ambulance Crew', 'Resuscitation Attempted - Bystander', 'Mechanically Assisted Cardiac Compressions', 'Not Attempted - Obvious Signs of Death', 'Not Attempted - DNR', 'Not Attempted - Signs of Circulation', 'Other']),
        FormFieldModel(id: 'returnSpontaneousCirculation', label: 'Return of spontaneous circulation', type: FieldType.dropdown, options: ['No ROSC achieved', 'ROSC on arrival at hospital', 'ROSC at any time']),
        FormFieldModel(id: 'CPRStart', label: 'CPR start time', type: FieldType.time),
        FormFieldModel(id: 'CPRStop', label: 'CPR stop time', type: FieldType.time),
        FormFieldModel(id: 'effortsCeased', label: 'Reason efforts ceased', type: FieldType.dropdown, options: ['DNAR', 'Medical Control Order', 'Obvious Signs of Death', 'ROSC', 'Other', 'Protocol / Policy Requirements Completed', 'Care Transferred to Hospital', 'Not Known (Bystander CPR)']),
        // Defibrillation
        FormFieldModel(id: 'defibrillationAttempted', label: 'Defibrillation attempted', type: FieldType.dropdown, options: ['Yes', 'No']),
        FormFieldModel(id: 'defibrillation_attempts', label: 'Total shocks administered', type: FieldType.number),
        // Defib Shock
        FormFieldModel(id: 'defibShock_type', label: 'Shock type', type: FieldType.dropdown, options: ['Defibrillation', 'Cardioversion', 'Pacing', 'Precordial Thump']),
        FormFieldModel(id: 'defibShock_energy', label: 'Shock energy (Joules)', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'defibShock_energyForm', label: 'Energy waveform', type: FieldType.dropdown, options: ['Monophasic', 'Biphasic']),
        FormFieldModel(id: 'defibShock_pacingType', label: 'Pacing type', type: FieldType.dropdown, options: ['Transcutaneous', 'Transvenous']),
      ],
    );
  }

  // ── 9. Treatment & Drugs ───────────────────────────────────────────
  static FormSection _treatmentAndDrugs() {
    return FormSection(
      id: 'treatment_drugs',
      title: 'Treatment & Drugs',
      fields: [
        // Drug Administration
        FormFieldModel(id: 'drugAdmin_name', label: 'Drug name', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'drugAdmin_route', label: 'Drug route', type: FieldType.dropdown, options: ['Endo Tracheal', 'Inhaled', 'Intra Nasal', 'Intraosseous', 'Intra Venous', 'Intra Muscular', 'Nebulised', 'Oral', 'Rectal', 'Sub Lingual/Buccal', 'Sub Cutaneous', 'Topical', 'Other']),
        FormFieldModel(id: 'drugAdmin_dosage', label: 'Drug dosage', type: FieldType.number),
        FormFieldModel(id: 'drugAdmin_batchNumber', label: 'Drug batch number', type: FieldType.text),
        FormFieldModel(id: 'drugAdmin_effect', label: 'Drug effect', type: FieldType.text),
        // Treatment
        FormFieldModel(id: 'treatmentType', label: 'Treatment type', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'treatment_administeredBy', label: 'Treatment administered by', type: FieldType.text),
        FormFieldModel(id: 'treatment_comments', label: 'Treatment comments', type: FieldType.text),
        FormFieldModel(id: 'treatmentTime', label: 'Treatment time', type: FieldType.time),
        // Intervention
        FormFieldModel(id: 'interventionType', label: 'Intervention type', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'interventionTime', label: 'Intervention time', type: FieldType.time),
        FormFieldModel(id: 'interventionComment', label: 'Intervention comment', type: FieldType.text),
        FormFieldModel(id: 'interventionBy', label: 'Intervention by', type: FieldType.text),
        // Cannulation
        FormFieldModel(id: 'cannulation_size', label: 'Cannula size', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'cannulation_side', label: 'Cannulation side', type: FieldType.dropdown, options: ['Left', 'Right']),
        FormFieldModel(id: 'cannulation_site', label: 'Cannulation site', type: FieldType.dropdown, options: ['ACF', 'Central Line', 'External jugular', 'Femoral', 'Forearm', 'Hand', 'Intraosseous', 'Lower extremity', 'Wrist', 'Other']),
        FormFieldModel(id: 'cannulation_outcome', label: 'Cannulation outcome', type: FieldType.text),
        FormFieldModel(id: 'cannulation_attempts', label: 'Cannulation attempts', type: FieldType.number),
        // Immobilisation
        FormFieldModel(id: 'immobilisation_location', label: 'Immobilisation body location', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'immobilisation_type', label: 'Immobilisation device type', type: FieldType.dropdown, options: ['Vacuum splint', 'Sling', 'Inflatable splint', 'Traction splint', 'Frac Straps', 'Box splint', 'C Spine Collar', 'Spine board', 'Extrication Device', 'Pelvic splint', 'Other']),
      ],
    );
  }

  // ── 10. Injury & Trauma ────────────────────────────────────────────
  static FormSection _injuryAndTrauma() {
    return FormSection(
      id: 'injury_trauma',
      title: 'Injury & Trauma',
      fields: [
        // Injury
        FormFieldModel(id: 'injury_activity', label: 'Injury activity type', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'injury_bodyLocation', label: 'Injury body location', type: FieldType.dropdown, options: ['Multiple', 'Head/neck / face', 'Spinal/spinal column', 'Chest', 'Abdominal/pelvic', 'Upper limbs', 'Lower limbs', 'Back', 'Other', 'Unknown']),
        FormFieldModel(id: 'injury_locationType', label: 'Injury location type', type: FieldType.dropdown, options: ['Home', 'Works/Industrial', 'Public Place', 'Leisure Facility', 'Healthcare Facility', 'Farm', "Water's Edge", 'Road/Pavement', 'Other']),
        FormFieldModel(id: 'safetyEquipmentUsed', label: 'Safety equipment used', type: FieldType.dropdown, options: ['None', 'Air Bag Deployed', 'Seat Belts', 'Child Safety Seat', 'Correctly adjusted head rests', 'Eye protection', 'Helmet', 'Other Protective Gear', 'Personal Flotation Device', 'Protective Clothing', 'Not Recorded / Undetermined']),
        // Mechanism of Injury
        FormFieldModel(id: 'injuryMechanism', label: 'Mechanism of injury', type: FieldType.dropdown, options: []),
        // Fall
        FormFieldModel(id: 'FallFromHeight', label: 'Fall distance (metres)', type: FieldType.number),
        // Burns
        FormFieldModel(id: 'burnSeverity', label: 'Burn severity', type: FieldType.dropdown, options: ['Full thickness', 'Partial Thickness', 'Superficial', 'Pertinent Negative']),
        // Spine
        FormFieldModel(id: 'spineStatus', label: 'Spine injury status', type: FieldType.dropdown, options: ['Suspected', 'Cleared']),
        // Road Vehicle
        FormFieldModel(id: 'roadVehicle_counterpart', label: 'Counterpart to crash', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'roadVehicle_occupantPosition', label: 'Occupant position in vehicle', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'roadVehicle_ejected', label: 'Patient ejected from vehicle', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'roadVehicle_vehicleType', label: 'Vehicle type', type: FieldType.dropdown, options: []),
        // Body Fluid IO
        FormFieldModel(id: 'fluidIO', label: 'Fluid intake or output', type: FieldType.dropdown, options: ['Input', 'Output']),
        FormFieldModel(id: 'fluidType', label: 'Fluid type', type: FieldType.dropdown, options: ['Blood', 'Emesis', 'Urine']),
        FormFieldModel(id: 'fluidVolume', label: 'Fluid volume', type: FieldType.number),
        // Lung Fields
        FormFieldModel(id: 'lungSoundDetails', label: 'Lung sound description', type: FieldType.text),
        FormFieldModel(id: 'lungLocation', label: 'Lung location', type: FieldType.dropdown, options: ['Top (apical)', 'Middle', 'Bottom']),
      ],
    );
  }

  // ── 11. Patient Management ─────────────────────────────────────────
  static FormSection _patientManagement() {
    return FormSection(
      id: 'patient_management',
      title: 'Patient Management',
      fields: [
        // Patient Management
        FormFieldModel(id: 'impressions', label: 'Impressions (condition description)', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'timeAtPatientsSide', label: "Time at patient's side", type: FieldType.time),
        // Observation
        FormFieldModel(id: 'observation_time', label: 'Observation time', type: FieldType.time),
        FormFieldModel(id: 'observer', label: 'Observer', type: FieldType.text),
        FormFieldModel(id: 'observationComments', label: 'Observation comments', type: FieldType.text),
        FormFieldModel(id: 'observationType', label: 'Observation type', type: FieldType.dropdown, options: []),
        // Crew
        FormFieldModel(id: 'crewPin', label: 'Crew payroll/personnel number', type: FieldType.text),
        // Care Professional
        FormFieldModel(id: 'careProfessional_role', label: 'Care professional role', type: FieldType.dropdown, options: ['Trust Crew', 'Trust ECP', 'Trust First Responder', 'Trust Other', 'Non-Trust GP', 'Non-Trust Community Responder', 'Non-Trust Other']),
        FormFieldModel(id: 'careProfessional_skillLevel', label: 'Highest skill level available', type: FieldType.dropdown, options: ['BASICS', 'Bystander', 'Community First Responder', 'Community Paramedic', 'Emergency Care Practitioner', 'Fire/Rescue', 'GP', 'Medical Team', 'Paramedic', 'Police', 'Technician', 'Other']),
        FormFieldModel(id: 'careProfessional_name', label: 'Care professional name', type: FieldType.text),
        FormFieldModel(id: 'careProfessional_id', label: 'Care professional ID', type: FieldType.text),
        // Educational Establishment
        FormFieldModel(id: 'eduEstablishment_relationship', label: 'Carer relationship to education facility', type: FieldType.dropdown, options: ['Carer', 'Headmaster', 'Lecturer', 'Teacher', 'School Nurse', 'Other']),
        FormFieldModel(id: 'eduEstablishment_orgName', label: 'Education facility name', type: FieldType.text),
        FormFieldModel(id: 'eduEstablishment_orgAddress', label: 'Education facility address', type: FieldType.text),
        // Vulnerable Adult and Safeguarding Children
        FormFieldModel(id: 'safeguarding_name', label: 'Primary carer name', type: FieldType.text),
        FormFieldModel(id: 'safeguarding_relationship', label: 'Carer relationship to patient', type: FieldType.text),
        FormFieldModel(id: 'safeguarding_carer', label: 'Social/family support type', type: FieldType.dropdown, options: ['Carer support', 'Domestic support', 'Living with family', 'Macmillan Nurse', 'Neighbours', 'Nursing support', 'Regular family', 'Self caring', 'Social Worker', 'Spouse', 'Other']),
        // Falls Assessment
        FormFieldModel(id: 'fallsAssessed', label: 'Falls assessment completed', type: FieldType.dropdown, options: ['Yes', 'No']),
      ],
    );
  }

  // ── 12. Disposition & Outcome ──────────────────────────────────────
  static FormSection _dispositionAndOutcome() {
    return FormSection(
      id: 'disposition_outcome',
      title: 'Disposition & Outcome',
      fields: [
        // Disposition
        FormFieldModel(id: 'destinationType', label: 'Destination type', type: FieldType.dropdown, options: ['Emergency Department', 'Direct Admission', 'GP', 'Home', 'Medical Assessment Unit', 'Minor Injury Unit', 'Non-NHS facility', 'Treated at Scene']),
        FormFieldModel(id: 'destinationHealthcareProvider', label: 'Destination healthcare provider', type: FieldType.text),
        FormFieldModel(id: 'disposition_CPROngoing', label: 'CPR ongoing at handover', type: FieldType.dropdown, options: ['Yes', 'No']),
        FormFieldModel(id: 'recipientGrade', label: 'Recipient grade', type: FieldType.text),
        FormFieldModel(id: 'recipientName', label: 'Recipient name', type: FieldType.text),
        FormFieldModel(id: 'disposition_arrivalTime', label: 'Arrival time at provider', type: FieldType.time),
        FormFieldModel(id: 'disposition_arrivalDate', label: 'Arrival date at provider', type: FieldType.date),
        FormFieldModel(id: 'handoverDate', label: 'Handover date', type: FieldType.date),
        FormFieldModel(id: 'handoverTime', label: 'Handover time', type: FieldType.time),
        // Provider Availability
        FormFieldModel(id: 'providerAvailability_firstChoice', label: 'First choice provider available', type: FieldType.dropdown, options: ['Yes', 'No']),
        FormFieldModel(id: 'providerAvailability_reason', label: 'Reason first choice unavailable', type: FieldType.text),
        FormFieldModel(id: 'providerAvailability_type', label: 'First choice provider type', type: FieldType.dropdown, options: ['Other Primary Care facility', 'Other Secondary Care facility', 'Walk in Centre', 'Other']),
        // Treated on Scene
        FormFieldModel(id: 'treatedOnScene_reason', label: 'Reason not transported', type: FieldType.dropdown, options: []),
        FormFieldModel(id: 'treatedOnScene_signedBy', label: 'Treated on scene - signed by', type: FieldType.text),
        FormFieldModel(id: 'treatedOnScene_signedByRole', label: 'Treated on scene - signer role', type: FieldType.dropdown, options: ['Crew', 'Named Patient', 'Carer', 'Child', 'Employee', 'Father', 'Mother', 'Partner', 'Spouse', 'GrandParent', 'Grandchild', 'Patient Advocate', 'Other Relative', 'Other']),
        FormFieldModel(id: 'treatedOnScene_unableReason', label: 'Reason statement not signed', type: FieldType.dropdown, options: ['Unavailable', 'Unconscious', 'Refused', 'Patient Condition', 'Other']),
        // Refuse Treatment
        FormFieldModel(id: 'refusalType', label: 'Refusal type', type: FieldType.dropdown, options: ['Refuse Treatment', 'Refuse Transport']),
        FormFieldModel(id: 'refusal_signedBy', label: 'Refusal signed by', type: FieldType.text),
        FormFieldModel(id: 'refusal_signedByRole', label: 'Refusal signer role', type: FieldType.dropdown, options: ['Crew', 'Named Patient', 'Carer', 'Child', 'Employee', 'Father', 'Mother', 'Partner', 'Spouse', 'GrandParent', 'Grandchild', 'Patient Advocate', 'Other Relative', 'Other']),
        FormFieldModel(id: 'refusal_unableReason', label: 'Reason refusal not signed', type: FieldType.dropdown, options: ['Unavailable', 'Unconscious', 'Refused', 'Patient Condition', 'Other']),
        // Life Extinct
        FormFieldModel(id: 'deathConfirmed', label: 'Death confirmed', type: FieldType.dropdown, options: ['Yes', 'No']),
        FormFieldModel(id: 'lifeExtinct_personRole', label: 'Person role confirming death', type: FieldType.dropdown, options: ['Crew', 'Doctor', 'Nurse', 'Other Healthcare Professional', 'Other']),
        FormFieldModel(id: 'lifeExtinct_personName', label: 'Person name confirming death', type: FieldType.text),
        FormFieldModel(id: 'lifeExtinct_reasonNotSigned', label: 'Reason confirmation not signed', type: FieldType.dropdown, options: ['Unavailable', 'Refused', 'Other']),
      ],
    );
  }
}
