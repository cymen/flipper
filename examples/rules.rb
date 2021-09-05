require 'bundler/setup'
require 'flipper'

class User < Struct.new(:id, :flipper_properties)
  include Flipper::Identifier
end

user = User.new(1, {
  "type" => "User",
  "id" => 1,
  "flipper_id" => "User;1",
  "plan" => "basic",
  "age" => 39,
  "roles" => ["team_user"]
})

admin_user = User.new(2, {
  "type" => "User",
  "id" => 2,
  "flipper_id" => "User;2",
  "roles" => ["admin", "team_user"],
})

other_user = User.new(3, {
  "type" => "User",
  "id" => 3,
  "flipper_id" => "User;3",
  "plan" => "plus",
  "age" => 18,
  "roles" => ["org_admin"]
})

age_rule = Flipper::Rules::Condition.new(
  {"type" => "property", "value" => "age"},
  {"type" => "operator", "value" => "gte"},
  {"type" => "integer", "value" => 21}
)
plan_rule = Flipper::Rules::Condition.new(
  {"type" => "property", "value" => "plan"},
  {"type" => "operator", "value" => "eq"},
  {"type" => "string", "value" => "basic"}
)
admin_rule = Flipper::Rules::Condition.new(
  {"type" => "string", "value" => "admin"},
  {"type" => "operator", "value" => "in"},
  {"type" => "property", "value" => "roles"}
)

puts "Single Rule"
###########################################################
p should_be_false: Flipper.enabled?(:something, user)
puts "Enabling single rule"
Flipper.enable_rule :something, plan_rule
p should_be_true: Flipper.enabled?(:something, user)
p should_be_false: Flipper.enabled?(:something, admin_user)
p should_be_false: Flipper.enabled?(:something, other_user)
puts "Disabling single rule"
Flipper.disable_rule :something, plan_rule
p should_be_false: Flipper.enabled?(:something, user)


puts "\n\nAny Rule"
###########################################################
any_rule = Flipper::Rules::Any.new(plan_rule, age_rule)
###########################################################
p should_be_false: Flipper.enabled?(:something, user)
puts "Enabling any rule"
Flipper.enable_rule :something, any_rule
p should_be_true: Flipper.enabled?(:something, user)
p should_be_false: Flipper.enabled?(:something, admin_user)
p should_be_false: Flipper.enabled?(:something, other_user)
puts "Disabling any rule"
Flipper.disable_rule :something, any_rule
p should_be_false: Flipper.enabled?(:something, user)


puts "\n\nAll Rule"
###########################################################
all_rule = Flipper::Rules::All.new(plan_rule, age_rule)
###########################################################
p should_be_false: Flipper.enabled?(:something, user)
puts "Enabling all rule"
Flipper.enable_rule :something, all_rule
p should_be_true: Flipper.enabled?(:something, user)
p should_be_false: Flipper.enabled?(:something, admin_user)
p should_be_false: Flipper.enabled?(:something, other_user)
puts "Disabling all rule"
Flipper.disable_rule :something, all_rule
p should_be_false: Flipper.enabled?(:something, user)


puts "\n\nNested Rule"
###########################################################
nested_rule = Flipper::Rules::Any.new(admin_rule, all_rule)
###########################################################
p should_be_false: Flipper.enabled?(:something, user)
p should_be_false: Flipper.enabled?(:something, admin_user)
p should_be_false: Flipper.enabled?(:something, other_user)
puts "Enabling nested rule"
Flipper.enable_rule :something, nested_rule
p should_be_true: Flipper.enabled?(:something, user)
p should_be_true: Flipper.enabled?(:something, admin_user)
p should_be_false: Flipper.enabled?(:something, other_user)
puts "Disabling nested rule"
Flipper.disable_rule :something, nested_rule
p should_be_false: Flipper.enabled?(:something, user)
p should_be_false: Flipper.enabled?(:something, admin_user)
p should_be_false: Flipper.enabled?(:something, other_user)

puts "\n\nBoolean Rule"
###########################################################
boolean_rule = Flipper::Rules::Condition.new(
  {"type" => "boolean", "value" => true},
  {"type" => "operator", "value" => "eq"},
  {"type" => "boolean", "value" => true},
)
###########################################################
Flipper.enable_rule :something, boolean_rule
p should_be_true: Flipper.enabled?(:something)
p should_be_true: Flipper.enabled?(:something, user)
Flipper.disable_rule :something, boolean_rule

puts "\n\nSet of Actors Rule"
###########################################################
set_of_actors_rule = Flipper::Rules::Condition.new(
  {"type" => "property", "value" => "flipper_id"},
  {"type" => "operator", "value" => "in"},
  {"type" => "array", "value" => ["User;1", "User;3"]},
)
###########################################################
Flipper.enable_rule :something, set_of_actors_rule
p should_be_true: Flipper.enabled?(:something, user)
p should_be_true: Flipper.enabled?(:something, other_user)
p should_be_false: Flipper.enabled?(:something, admin_user)
Flipper.disable_rule :something, set_of_actors_rule
