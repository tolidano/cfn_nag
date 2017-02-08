require_relative 'model/parser_registry'
require_relative 'model/cfn_model'

class CustomRuleLoader

  @custom_rule_directory = '/var/lib/cfn_nag_plugins'

  def self.custom_rule_directory=(directory)
    @custom_rule_directory = directory
  end

  def self.custom_rule_directory
    @custom_rule_directory
  end

  def initialize
    @custom_rule_registry = [
      SecurityGroupMissingEgressRule,
      UserMissingGroupRule,
      UnencryptedS3PutObjectAllowedRule
    ]
    @violations = []
  end

  def custom_rules(input_json)
    discover_rules
    @custom_rule_registry.each do |rule_class|
      rule = rule_class.new
      if rule.respond_to? 'custom_parsers'
        rule.custom_parsers.each do |custom_parser|
          ParserRegistry.instance.add_parser custom_parser[0], custom_parser[1]
        end
      end

      cfn_model = CfnModel.new.parse(input_json)
      audit_result = rule_class.new.audit(cfn_model)
      @violations << audit_result unless audit_result.nil?
    end
    @violations
  end

  private

  def discover_rules(rule_directory: CustomRuleLoader.custom_rule_directory)
    rules = Dir[File.join(rule_directory, '*Rule.rb')].sort

    rules.each do |rule|
      require(rule)
      @custom_rule_registry << Object.const_get(File.basename(rule, '.rb'))
    end
  end
end