/*
 * This software was developed at the National Institute of Standards and
 * Technology (NIST) by employees of the Federal Government in the course
 * of their official duties. Pursuant to title 17 Section 105 of the
 * United States Code, this software is not subject to copyright protection
 * and is in the public domain. NIST assumes no responsibility whatsoever for
 * its use by other parties, and makes no guarantees, expressed or implied,
 * about its quality, reliability, or any other characteristic.
 */

#ifndef FOFRA2018_H_
#define FOFRA2018_H_

#include <cstdint>
#include <iostream>
#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace FOFRA {

/**
 * @brief
 * Return codes for functions specified in this API
 */
enum class ReturnCode {
    /** Success */
    Success = 0,
    /** Error reading configuration files */
    ConfigError,
    /** Cannot parse the input data */
    ParseError,
    /** Elective refusal to produce a fused template (e.g. too little information) */
    TemplateCreationError,
    /** Either or both of the input templates were result of failed
     * feature extraction */
    VerifTemplateError,
    /** The implementation cannot support the number of input data */
    NumDataError,
    /** Template file is an incorrect format or defective */
    TemplateFormatError,
    /** Cannot locate the input data - the input files or names seem incorrect */
    InputLocationError,
    /** Memory allocation failed (e.g. out of memory) */
    MemoryError,
    /** Function is not implemented */
    NotImplemented,
    /** Vectors of different lengths passed to function expecting same lengths */
    NonCongruentVectors,
    /** Vendor-defined failure */
    VendorError
};

/** Output stream operator for a ReturnCode object. */
inline std::ostream&
operator<<(
    std::ostream &s,
    const ReturnCode &rc)
{
    switch (rc) {
    case ReturnCode::Success:
        return (s << "Success");
    case ReturnCode::ConfigError:
        return (s << "Error reading configuration files");
    case ReturnCode::ParseError:
        return (s << "Cannot parse the input data");
    case ReturnCode::TemplateCreationError:
        return (s << "Elective refusal to produce a template");
    case ReturnCode::VerifTemplateError:
        return (s << "Either/both input templates were result of failed feature extraction");
    case ReturnCode::NumDataError:
        return (s << "Number of input images not supported");
    case ReturnCode::TemplateFormatError:
        return (s << "Template file is an incorrect format or defective");
    case ReturnCode::InputLocationError:
        return (s << "Cannot locate the input data - the input files or names seem incorrect");
    case ReturnCode::MemoryError:
        return (s << "Memory allocation failed (e.g. out of memory)");
    case ReturnCode::NonCongruentVectors:
        return (s << "Vectors of different lengths passed to function expecting same lengths");
    case ReturnCode::NotImplemented:
        return (s << "Function is not implemented");
    case ReturnCode::VendorError:
        return (s << "Vendor-defined error");
    default:
        return (s << "Undefined error");
    }
}

/**
 * @brief
 * A structure to contain information about a failure by the software
 * under test.
 *
 * @details
 * An object of this class allows the software to return some information
 * from a function call. The string within this object can be optionally
 * set to provide more information for debugging etc. The status code
 * will be set by the function to Success on success, or one of the
 * other codes on failure.
 */
struct ReturnStatus {
    /** @brief Return status code */
    ReturnCode code;
    /** @brief Optional information string */
    std::string info;

    ReturnStatus() {}
    /**
     * @brief
     * Create a ReturnStatus object.
     *
     * @param[in] code
     * The return status code; required.
     * @param[in] info
     * The optional information string.
     */
    ReturnStatus(
        const ReturnCode code,
        const std::string &info = ""
        ) :
        code{code},
        info{info}
        {}
};
using ReturnStatus = struct ReturnStatus;

/**
 * @brief
 * A set of scores, some genuine, some impostor
 */
using ScoreSet = std::vector<double>;

/**
 * @brief
 * Data structure for result of an identification search
 */
struct Candidate {
    /** @brief Identity hypothesis, a valid gallery identity label */
    uint32_t identity;

    /** @brief Similarity score from recognition or fusion */
    double score;

    Candidate() :
        identity{0},
        score{0.0}
        {}

    Candidate(
        uint32_t identity,
        double score) :
        identity{identity},
        score{score}
        {}
};
using Candidate = struct Candidate;

/**
 * @brief
 * A set of scores and hypothesized identities
 */
using CandidateList = std::vector<Candidate>;

/**
 * @brief
 * Features for recognition
 */
using Template = std::vector<double>;


/**
 * @brief
 * The interface to a score fuser of verification scores and
 * identification candidate lists.
 *
 * @details
 * The submission software under test will implement this interface by
 * sub-classing this class and implementing each method therein.
 */
class ScoreFuserInterface {
public:
    enum class Type {
        Verification = 0,
        Identification = 1
    };

    virtual ~ScoreFuserInterface() {}

    /**
     * @brief
     * The function reads a pre-computed fusion scheme from the provided
     * directory (e.g. pre-trained models), including any normalization information.
     * The contents of the directory are developer-defined and are provided to
     * NIST by the developer.  It will be called by the NIST application before
     * any call to fuseVerificationScores or fuseCandidateLists().
     *
     * @param[in] directory
     * A read-only directory containing any developer-supplied configuration
     * parameters or run-time data files.  The name of this directory is
     * assigned by NIST, not hardwired by the provider.  The names of the
     * files in this directory are hardwired in the implementation and are
     * unrestricted.
     * @param[in] type
     * Enum indicating which fusion scheme/model the implementation should load
     * Type::Verification - load pre-computed fusion scheme for verification
     * score fusion
     * Type::Identification - load pre-computed fusion scheme for identification
     * candidate list fusion
     */
    virtual ReturnStatus
    initialize(
        const std::string &directory,
        const ScoreFuserInterface::Type &type) = 0;

    /**
     * @brief
     * Function to execute fusion. Given K ≥ 2 scores, each from a
     * different algorithms, it produces one fused score.
     *
     * @param[in] inputScores
     * K ≥ 2 scores
     * @param[out] fusedScore
     * A fused score.
     */
    virtual ReturnStatus
    fuseVerificationScores(
        const ScoreSet &inputScores,
        double &fusedScore) = 0;

    /**
     * @brief
     * Function to execute fusion of candidate lists. Given K ≥ 2
     * candidate lists, each from a different algorithm, it produces one output
     * candidate list.
     * All input lists have the same length, L. The output fusedLists will
     * initially be an empty vector.  The output list may have
     * variable length L ≤ x ≤ 2L.
     *
     * @param[in] inputLists
     * Given K ≥ 2 vectors of candidate lists
     * @param[out] outputFused
     * A vector of fused candidate lists
     */
    virtual ReturnStatus
    fuseCandidateLists(
        const std::vector<CandidateList> &inputLists,
        CandidateList &fusedList) = 0;

    /**
     * @brief
     * Factory method to return a managed pointer to the
     * ScoreFuserInterface object.
     *
     * @details
     * This function is implemented by the submitted library and must return
     * a managed pointer to the ScoreFuserInterface object.
     *
     * @note
     * A possible implementation might be:
     * return (std::make_shared<Implementation>());
     */
    static std::shared_ptr<ScoreFuserInterface>
    getImplementation();
};

/**
 * @brief
 * The interface to a template fuser.
 *
 * @details
 * The submission software under test will implement this interface by
 * sub-classing this class and implementing each method therein.
 */
class TemplateFuserInterface {
public:
    enum class Action {
        Fuse = 0,
        Verify,
        Identify
    };
    virtual ~TemplateFuserInterface() {}

    /**
     * @brief
     * This function initializes the capability as specified via the action parameter:
     * Action::Fuse - reads a pre-computed fusion scheme from the provided directory
     *     (e.g. pre-trained models), including any normalization information.
     * Action::Verify - Initialize a verifier.  The directory must contain
     *     sufficient information to identify which algorithms were fused and to
     *     load an appropriate verifier.
     * Action::Identify - Initialize an identifier.  The directory must contain
     *     sufficient information to identity which algorithms were fused and to
     *     load an appropriate identifier.
     *
     * The contents of the directory are developer-defined and are provided
     * to NIST by the developer.
     *
     * @param[in] directory
     * A read-only directory containing any developer-supplied configuration
     * parameters or run-time data files.  The name of this directory is
     * assigned by NIST, not hardwired by the provider.  The names of the
     * files in this directory are hardwired in the implementation and are
     * unrestricted.
     * @param[in] action
     * The functionality to initialize
     */
    virtual ReturnStatus
    initialize(
        const std::string &directory,
        const TemplateFuserInterface::Action &action) = 0;

    /**
     * @brief
     * Function to execute fusion. This function will be preceded by a call to
     * initialize(action = Action::Fuse).  Given a vector of templates
     * (presumably generated from different algorithms), the implementation
     * produces one template, which is the fusion between all input templates.
     *
     * @param[in] inputTemplates
     * K ≥ 2 templates
     * @param[out] fusedTemplate
     * A fused template
     */
    virtual ReturnStatus
    fuseTemplates(
       const std::vector<Template> &inputTemplates,
       Template &fusedTemplate) = 0;

    /**
     * @brief
     * Given fused templates, the implementation must support one-to-one
     * comparison of two such templates via this function.  Compare an
     * authentication template with an enrollment template and return a
     * similarity score.  This function will be preceded by a call to
     * initialize(action = Action::Verify).
     *
     * @param[in] enroll, authentication
     * Fused templates
     * @param[out] score
     * Similarity score
     */
    virtual ReturnStatus
    verify(
        const Template &enroll,
        const Template &authentication,
        double &score) = 0;

    /**
     * @brief
     * This function creates a gallery by adding a set of N identified templates
     * to the implementation’s internal gallery structure.  This function should
     * copy or otherwise process the input so that searches can follow.  This
     * function will be preceded by a call to initialize(action = Action::Identify).
     * The provided templates will contain N templates of N identities or people.
     *
     * @param[in] templates
     * A vector of fused templates
     * @param[in] ids
     * A vector of identities, associated with the vector of input templates
     * ids[i] corresponds to templates[i]
     */
    virtual ReturnStatus
    createGallery(
        const std::vector<Template> &templates,
        const std::vector<uint32_t> &ids) = 0;

    /**
     * @brief
     * Search a probe template against the gallery and fill the pre-allocated
     * candidate list with hypothesized candidates.  This function will be
     * preceded by a call to initialize(action=Action::Identify) and
     * createGallery().  The number of candidates to populate is specified by
     * candidates.size().
     *
     * @param[in] probe
     * Probe template to search
     * @param[out] candidates
     * Output candidate list populated with hypothesized candidates
     */
    virtual ReturnStatus
    search(
        const Template &probe,
        CandidateList &candidates) = 0;

    /**
     * @brief
     * Factory method to return a managed pointer to the
     * TemplateFuserInterface object.
     *
     * @details
     * This function is implemented by the submitted library and must return
     * a managed pointer to the TemplateFuserInterface object.
     *
     * @note
     * A possible implementation might be:
     * return (std::make_shared<Implementation>());
     */
    static std::shared_ptr<TemplateFuserInterface>
    getImplementation();
};
}

#endif /* FOFRA2018_H_ */
