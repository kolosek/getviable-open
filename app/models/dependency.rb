module Surveyor
  module Models
    module DependencyMethods
      def self.included(base)
        # Associations
        base.send :belongs_to, :question
        base.send :belongs_to, :question_group
        base.send :has_many, :dependency_conditions, :dependent => :destroy
        
        @@validations_already_included ||= nil
        unless @@validations_already_included
          # Validations
          base.send :validates_presence_of, :rule
          base.send :validates_format_of, :rule, :with => /^(?:and|or|\)|\(|[A-Z]|\s)+$/ #TODO properly formed parenthesis etc.
          #base.send :validates_numericality_of, :question_id, :if => Proc.new { |d| d.question_group_id.nil? }
          #base.send :validates_numericality_of, :question_group_id, :if => Proc.new { |d| d.question_id.nil? }
          
          @@validations_already_included = true
        end
        
        # Whitelisting attributes
        base.send :attr_accessible, :question, :question_group, :question_id, :question_group_id, :rule
        
        # Attribute aliases
        base.send :alias_attribute, :dependent_question_id, :question_id
      end

      # Instance Methods
      def question_group_id=(i)
        write_attribute(:question_id, nil) unless i.nil?
        write_attribute(:question_group_id, i)
      end

      def question_id=(i)
        write_attribute(:question_group_id, nil) unless i.nil?
        write_attribute(:question_id, i) 
      end

      # Has this dependency has been met in the context of response_set?
      # Substitutes the conditions hash into the rule and evaluates it
      def is_met?(response_set)
        ch = conditions_hash(response_set)
        return false if ch.blank?
        # logger.debug "rule: #{self.rule.inspect}"
        # logger.debug "rexp: #{rgx.inspect}"
        # logger.debug "keyp: #{ch.inspect}"
        # logger.debug "subd: #{self.rule.gsub(rgx){|m| ch[m.to_sym]}}"
        rgx = Regexp.new(self.dependency_conditions.map{|dc| ["a","o"].include?(dc.rule_key) ? "\\b#{dc.rule_key}(?!nd|r)\\b" : "\\b#{dc.rule_key}\\b"}.join("|")) # exclude and, or
        eval(self.rule.gsub(rgx){|m| ch[m.to_sym]})
      end

      # A hash of the conditions (keyed by rule_key) and their evaluation (boolean) in the context of response_set
      def conditions_hash(response_set)
        hash = {}
        self.dependency_conditions.each{|dc| hash.merge!(dc.to_hash(response_set))}
        return hash
      end
    end
  end
end

class Dependency < ActiveRecord::Base
  unloadable
  include Surveyor::Models::DependencyMethods

  accepts_nested_attributes_for :dependency_conditions, :allow_destroy => true
  attr_accessible :dependency_conditions_attributes

  def custom_unparse(dsl)
    attrs = (self.attributes.diff Dependency.new.attributes).delete_if{|k,v| %w(created_at updated_at id question_id).include?(k) }.symbolize_keys!
    dsl << "  " if question.part_of_group?
    dsl << "    dependency"
    dsl << (attrs.blank? ? "\n" : " #{attrs.inspect.gsub(/\{|\}/, "")}\n")
    dependency_conditions.each{|dependency_condition| dependency_condition.custom_unparse(dsl)}
  end
end