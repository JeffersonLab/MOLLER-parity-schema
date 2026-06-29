-- ============================================================================
-- MOLLER Parity schema
-- This database schema is used to populate data produced during the integration mode running of
-- MOLLER experiment
-- 
-- Author : Buddhini Waidyawansa
-- contact: waidya@jlab.org
-- Last updated: 06-25-2026
-- -----------------------------


-- ============================================================================
-- 1. REFERENCE TABLES (No Foreign Key Dependencies)
-- ============================================================================
-- Table to store db information
CREATE TABLE db_schema (
    db_schema_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    major_release_number CHAR(2) NOT NULL,
    minor_release_number CHAR(2) NOT NULL,
    point_release_number CHAR(4) NOT NULL,
    time TIMESTAMP NOT NULL,
    script_name TEXT,
    INDEX idx_schema_time (time)
);

-- Table to store what run is good_for e.g production, calibration, optics etc
CREATE TABLE good_for (
    good_for_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    description TEXT
);

-- Table to store error codes. CHECK
-- See japan-MOLLER/Analysis/include/QwTypes.h for the full list
CREATE TABLE error_code (
    error_code_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    description TEXT NOT NULL
);

-- Table to store measurement types.
-- using a reference table instead of enum for ease of adding new types later
CREATE TABLE measurement_type (
    measurement_type_id CHAR(3) PRIMARY KEY,
    units VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL
);

-- Table to store detector types
-- using a reference table instead of enum for ease of adding new types later
CREATE TABLE detector_type (
    detector_type_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    detector VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    INDEX idx_detector_type_name (detector)
);

-- Table to store names and types of all slow control detector elements shown in "slow" root tree
CREATE TABLE slow_control_detector (
    slow_control_detector_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    units VARCHAR(50) NOT NULL,
    comment TEXT NOT NULL,
    INDEX idx_sc_detector_name (name)
);

-- Table to store modulation types. CHECK. do we need this? can we use enum?
CREATE TABLE modulation_type (
    modulation_type_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    type VARCHAR(255)
);

-- ============================================================================
-- 2. CORE EXPERIMENTAL ENTITIES & TIME WINDOWS
-- ============================================================================

-- Table to store names and types of all moller detector elements shown in "muls" root tree
CREATE TABLE detector (
    detector_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    detector_type_id INT UNSIGNED NOT NULL,
    name VARCHAR(255) NOT NULL UNIQUE, -- Changed from TEXT to indexed VARCHAR
    units VARCHAR(255),
    description TEXT,
    INDEX idx_detector_name (name),
    INDEX idx_detector_type_enum (detector_type_id),
    CONSTRAINT fk_detector_type FOREIGN KEY (detector_type_id) REFERENCES detector_type (detector_type_id)
);

-- Table to store run and runlet information provided by the japan-moller analyzer
CREATE TABLE data_taking_period (
    period_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    period_type ENUM('run', 'segment'),
    parent_id INT UNSIGNED DEFAULT NULL,
    run_number INT UNSIGNED NOT NULL,
    segment_number SMALLINT DEFAULT NULL,
    good_for_id INT UNSIGNED NOT NULL,
    data_quality ENUM('good', 'bad', 'suspect') NOT NULL,
    slug_number SMALLINT NOT NULL,
    wien_number SMALLINT NOT NULL,
    full_run BOOLEAN NOT NULL DEFAULT TRUE,
    start_time TIMESTAMP NULL DEFAULT NULL,
    end_time TIMESTAMP NULL DEFAULT NULL,
    tz_offset VARCHAR(32),
    first_minipulses INT UNSIGNED,
    last_minipulses INT UNSIGNED,
    num_minipulses BIGINT UNSIGNED NOT NULL,
    num_quartets BIGINT UNSIGNED NOT NULL,
    comment TEXT,
    UNIQUE KEY uq_period_run_segment (run_number, segment_number),
    INDEX idx_period_type_hierarchy (period_type, parent_id),
    INDEX idx_period_slugs (slug_number, wien_number),
    INDEX idx_period_times (start_time, end_time),
    CONSTRAINT fk_period_parent FOREIGN KEY (parent_id) REFERENCES data_taking_period (period_id),
    CONSTRAINT fk_period_good_for FOREIGN KEY (good_for_id) REFERENCES good_for (good_for_id)
);

-- Table to store blinder seeds
CREATE TABLE seeds (
    seed_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_period_id INT UNSIGNED NOT NULL,
    last_period_id INT UNSIGNED NOT NULL,
    seed TEXT,
    comment TEXT,
    CONSTRAINT fk_seeds_first_period FOREIGN KEY (first_period_id) REFERENCES data_taking_period (period_id),
    CONSTRAINT fk_seeds_last_period FOREIGN KEY (last_period_id) REFERENCES data_taking_period (period_id)
);

-- Table to store analysis information 
CREATE TABLE analysis (
    analysis_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    period_id INT UNSIGNED NOT NULL,
    seed_id INT UNSIGNED NOT NULL,
    time TIMESTAMP NULL DEFAULT NULL,
    bf_checksum VARCHAR(64),
    beam_mode ENUM('natural', 'pulsed'),
    regression_status BOOLEAN NOT NULL DEFAULT FALSE,
    rntuple_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    root_version VARCHAR(50) NOT NULL,
    root_file_time VARCHAR(100) NOT NULL,
    root_file_host VARCHAR(100) NOT NULL,
    root_file_user VARCHAR(100) NOT NULL,
    analyzer_name VARCHAR(100) NOT NULL,
    analyzer_argv TEXT NOT NULL,
    analyzer_svn_rev VARCHAR(50) NOT NULL,
    analyzer_svn_lc_rev VARCHAR(50) NOT NULL,
    analyzer_svn_url TEXT NOT NULL,
    roc_flags TEXT NOT NULL,
    git_commit_sha CHAR(40),
    docker_image_digest VARCHAR(100),
    parameter_files JSON,
    -- INDEX idx_analysis_seed (seed_id),
    -- INDEX idx_analysis_git (git_commit_sha),
    -- INDEX idx_analysis_docker (docker_image_digest),
     -- Composite index to optimize downstream view joins
	INDEX `idx_analysis_period_perf` (`analysis_id`, `period_id`),
    CONSTRAINT fk_analysis_period FOREIGN KEY (period_id) REFERENCES data_taking_period (period_id),
    CONSTRAINT fk_analysis_seed FOREIGN KEY (seed_id) REFERENCES seeds (seed_id)
);

-- ============================================================================
-- MEASUREMENTS, SLOW CONTROLS & DIAGNOSTIC DATA
-- ============================================================================

-- Table to store general error codes in detector elements
-- This will be based on the error codes shown in QwTypes.h
CREATE TABLE general_errors (
    general_errors_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    analysis_id INT UNSIGNED NOT NULL,
    error_code_id INT UNSIGNED NOT NULL,
    num_events BIGINT UNSIGNED NOT NULL,
    CONSTRAINT fk_gen_err_analysis FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id),
    CONSTRAINT fk_gen_err_code FOREIGN KEY (error_code_id) REFERENCES error_code (error_code_id)
);

-- Table to store data analyzed from all moller detector elements
-- QUESTION for Paul : Do we need to add the moments here? hw_sum_m2 and hw_sum_err?
CREATE TABLE detector_data (
    detector_data_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    detector_type_id INT UNSIGNED NOT NULL,
    analysis_id INT UNSIGNED NOT NULL,
    detector_id INT UNSIGNED,
    measurement_type_id CHAR(3) NOT NULL,
    error_code_id INT UNSIGNED NOT NULL,
    error_code_n TINYINT NOT NULL,
    sub_block SMALLINT NOT NULL,
    num_minipulses BIGINT UNSIGNED NOT NULL,
    value FLOAT NOT NULL,
    error FLOAT NOT NULL,
    
    INDEX idx_det_data_lookup (analysis_id, detector_id, measurement_type_id, sub_block, value, error),
    INDEX idx_det_data_type_fk (detector_type_id),
    INDEX idx_det_data_err_fk (error_code_id),
    INDEX idx_det_data_measure_fk (measurement_type_id),

    CONSTRAINT fk_det_data_type FOREIGN KEY (detector_type_id) REFERENCES detector_type (detector_type_id),
    CONSTRAINT fk_det_data_analysis FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id),
    CONSTRAINT fk_det_data_detector FOREIGN KEY (detector_id) REFERENCES detector (detector_id),
    CONSTRAINT fk_det_data_meas_type FOREIGN KEY (measurement_type_id) REFERENCES measurement_type (measurement_type_id),
    CONSTRAINT fk_det_data_err FOREIGN KEY (error_code_id) REFERENCES error_code (error_code_id)
);


-- Table to store the correlation matrix. 
-- These are the sensitivities and corrections calculated by GrandCorrelator class.
-- Each 500x500 matrix is store as a json blob.
CREATE TABLE grand_correlator (
    correlator_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    analysis_id INT UNSIGNED NOT NULL,
    matrix JSON NOT NULL,
    CONSTRAINT fk_grand_corr_analysis FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id)
);

-- Table to store the sensitivities (linear correlation) calculated by grand correlator for 
-- selected detector pairs needing immediate access for diagnostics
CREATE TABLE selected_sensitivities (
    sensitivity_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    analysis_id INT UNSIGNED NOT NULL,
    independant_detector_id INT UNSIGNED NOT NULL,
    dependant_detector_id INT UNSIGNED NOT NULL,
    measurement_type_id CHAR(3) NOT NULL,
    per_pair_good_count INT UNSIGNED NOT NULL,
    slope FLOAT NOT NULL,
    error FLOAT NOT NULL,
    CONSTRAINT fk_sens_analysis FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id),
    CONSTRAINT fk_sens_indep_det FOREIGN KEY (independant_detector_id) REFERENCES detector (detector_id),
    CONSTRAINT fk_sens_dep_det FOREIGN KEY (dependant_detector_id) REFERENCES detector (detector_id),
    CONSTRAINT fk_sens_meas_type FOREIGN KEY (measurement_type_id) REFERENCES measurement_type (measurement_type_id)
);


-- Table to store slow control settings such as ihwp status
CREATE TABLE slow_controls_settings (
    slow_controls_settings_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    period_id INT UNSIGNED NOT NULL,
    slow_helicity_plate ENUM('out', 'in'),
    passive_helicity_plate ENUM('out', 'in'),
    wien_reversal ENUM('indeterminate', 'normal', 'reverse', 'transverse_vertical', 'transverse_horizontal'),
    precession_reversal ENUM('CCW', 'CW', 'reverse', 'normal'),
    helicity_window_length INT NULL,
    charge_feedback ENUM('off', 'on'),
    position_feedback ENUM('off', 'on'),
    target_position TEXT,
    INDEX idx_sc_settings_lookup (period_id, slow_helicity_plate),
    CONSTRAINT fk_sc_settings_period FOREIGN KEY (period_id) REFERENCES data_taking_period (period_id)
);

-- Table to store all data from slow controls detectors
CREATE TABLE slow_controls_data (
    slow_controls_data_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    period_id INT UNSIGNED NOT NULL,
    slow_control_detector_id INT UNSIGNED NOT NULL,
    num_events BIGINT UNSIGNED NOT NULL,
    value FLOAT NOT NULL,
    error FLOAT NOT NULL,
    min_value FLOAT NOT NULL,
    max_value FLOAT NOT NULL,
    INDEX idx_sc_data_period_det (period_id, slow_control_detector_id),
    CONSTRAINT fk_sc_data_period FOREIGN KEY (period_id) REFERENCES data_taking_period (period_id),
    CONSTRAINT fk_sc_data_detector FOREIGN KEY (slow_control_detector_id) REFERENCES slow_control_detector (slow_control_detector_id)
);

-- Table to store the blinder test results
CREATE TABLE bf_test (
    bf_test_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    analysis_id INT UNSIGNED NOT NULL,
    test_number SMALLINT,
    test_value FLOAT,
    CONSTRAINT fk_bf_test_analysis FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id)
);

-- Table to store beam modulation system related information
-- QUESTION FOR Kent: this is from Qweak. will need to update for MOLLER?
CREATE TABLE beam_modulation (
    beam_mod_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    analysis_id INT UNSIGNED NOT NULL,
    monitor_id INT UNSIGNED NOT NULL, -- Links to detector_id
    modulation_type_id INT UNSIGNED NOT NULL,
    num_events BIGINT UNSIGNED NOT NULL,
    amplitude FLOAT NOT NULL,
    phase FLOAT NOT NULL,
    offset FLOAT NOT NULL,
    a_error FLOAT NOT NULL,
    p_error FLOAT NOT NULL,
	o_error FLOAT NOT NULL,
    gof_para FLOAT NOT NULL,
    INDEX idx_beam_modulation_lookup (analysis_id, monitor_id),
    CONSTRAINT fk_beam_mod_analysis FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id),
    CONSTRAINT fk_beam_mod_monitor FOREIGN KEY (monitor_id) REFERENCES detector (detector_id),
    CONSTRAINT fk_beam_mod_type FOREIGN KEY (modulation_type_id) REFERENCES modulation_type (modulation_type_id)
    );
    
    
-- ============================================================================
-- VIEWS (VIRTUAL TABLES)
-- Internally stored queries for easy access of most commonly required plots
-- ============================================================================

-- get all run/runlets values from good data for all detectors and sensitivities
CREATE OR REPLACE VIEW view_slug_summaries AS
SELECT 
    p.slug_number,
    p.period_id,
    p.run_number,
    p.segment_number,
    a.analysis_id,
    
    -- Detector Data Attributes
    dd.detector_data_id,
    dd.detector_id,
    d.name AS detector_name,
    dt.detector AS detector_type,
    dd.measurement_type_id,
    dd.value AS detector_value,
    dd.error AS detector_error,
    
    -- Linked Sensitivity / Regression Attributes
    ss.sensitivity_id,
    ss.independant_detector_id,
    ss.slope AS sensitivity_slope,
    ss.error AS sensitivity_slope_error,
    ss.per_pair_good_count
    
FROM data_taking_period p
-- Ensure we only loop through valid, completed analysis entries
JOIN analysis a ON p.period_id = a.period_id
-- Pull the detector measurements 
JOIN detector_data dd ON a.analysis_id = dd.analysis_id
-- Pull detector names
JOIN detector d ON  dd.detector_id = d.detector_id
-- Pull detector type
JOIN detector_type dt ON d.detector_type_id = dt.detector_type_id
-- Match sensitivities where the current detector acts as the dependent variable
LEFT JOIN selected_sensitivities ss ON a.analysis_id = ss.analysis_id
    AND dd.detector_id = ss.dependant_detector_id
    AND dd.measurement_type_id = ss.measurement_type_id
-- Enforce data quality
WHERE p.data_quality = 'good'
  AND dd.error IS NOT NULL
  AND dd.error > 0;


-- ============================================================================
-- SUMMARY TABLES
-- ============================================================================

-- slug aggregated summaries
CREATE TABLE summary_slug_detector_metrics (
    slug_number SMALLINT NOT NULL,
    slow_helicity_plate_status ENUM('out', 'in') NOT NULL,
    detector_id INT UNSIGNED NOT NULL,
    detector_type_id INT UNSIGNED NOT NULL,
    measurement_type_id CHAR(3) NOT NULL,
    weighted_avg_value DOUBLE NOT NULL COMMENT 'Statistical inverse-variance weighted mean',
    weighted_avg_error DOUBLE NOT NULL COMMENT 'Propagated standard error of the weighted mean',
    total_runlets_aggregated INT UNSIGNED NOT NULL,
    total_minipulses_aggregated BIGINT UNSIGNED NOT NULL COMMENT 'Sum of all integrated mini-pulses',
    min_observed_value FLOAT NOT NULL,
    max_observed_value FLOAT NOT NULL,
    last_updated_period TIMESTAMP NULL,
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- PRIMARY KEY: Optimized for slug/plate extraction and detector joins.
    -- (InnoDB clusters the physical table rows on disk in this exact order)
    PRIMARY KEY (slug_number, slow_helicity_plate_status, detector_id, measurement_type_id, detector_type_id),
    
    -- FOREIGN KEY CONSTRAINTS
    CONSTRAINT fk_summary_slug_detector FOREIGN KEY (detector_id) REFERENCES detector (detector_id),
    CONSTRAINT fk_summary_slug_det_type FOREIGN KEY (detector_type_id) REFERENCES detector_type (detector_type_id),
    CONSTRAINT fk_summary_slug_meas_type FOREIGN KEY (measurement_type_id) REFERENCES measurement_type (measurement_type_id)
);



-- ============================================================================
-- LOGS
-- ============================================================================

CREATE TABLE event_execution_log (
    log_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_name VARCHAR(100) NOT NULL,
    execution_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('STARTED', 'COMPLETED', 'FAILED') NOT NULL,
    message TEXT
);