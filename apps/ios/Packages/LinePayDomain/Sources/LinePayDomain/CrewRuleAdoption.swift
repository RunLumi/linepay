import Foundation

/// Retains the original worker draft and the recipient's choices, without source-approval claims.
public struct CrewRuleAdoption: Codable, Hashable, Sendable {
    public let templateData: Data
    public let hourlyRate: Money
    public let perDiemChoice: CrewRuleTemplate.PerDiemChoice
    public let perDiemAmount: Money?

    public init(
        templateData: Data, hourlyRate: Money, perDiemChoice: CrewRuleTemplate.PerDiemChoice,
        perDiemAmount: Money? = nil, applicabilityConfirmed: Bool, valuesConfirmed: Bool
    ) throws {
        self.templateData = templateData
        self.hourlyRate = hourlyRate
        self.perDiemChoice = perDiemChoice
        self.perDiemAmount = perDiemAmount
        let packet = try CrewRuleTemplate.decode(templateData)
        _ = try packet.proposeAgreement(
            newAgreementID: packet.templateID, hourlyRate: hourlyRate,
            perDiemChoice: perDiemChoice, perDiemAmount: perDiemAmount,
            applicabilityConfirmed: applicabilityConfirmed, valuesConfirmed: valuesConfirmed)
    }

    public func proposedAgreement(newAgreementID: UUID) throws -> AgreementSnapshot {
        try CrewRuleTemplate.decode(templateData).proposeAgreement(
            newAgreementID: newAgreementID, hourlyRate: hourlyRate, perDiemChoice: perDiemChoice,
            perDiemAmount: perDiemAmount, applicabilityConfirmed: true, valuesConfirmed: true)
    }

    /// Decode is not validation. Reproduce terms before admitting a stored adoption or new version.
    public func validate(agreement: AgreementSnapshot) throws {
        let packet = try CrewRuleTemplate.decode(templateData)
        let expected = try proposedAgreement(newAgreementID: packet.templateID)
        let actualRules = try CrewRuleTemplate.sharing(
            agreement, templateID: packet.templateID, revision: packet.revision,
            title: packet.title, includeAmounts: true
        ).rules
        let expectedRules = try CrewRuleTemplate.sharing(
            expected, templateID: packet.templateID, revision: packet.revision,
            title: packet.title, includeAmounts: true
        ).rules
        guard actualRules == expectedRules else { throw CrewRuleTemplateError.confirmationRequired }
    }
}
