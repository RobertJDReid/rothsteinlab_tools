FactoryGirl.define do 
	factory :user do
    sequence(:email) { |n| "foo#{n}@example.com" }
    password "foobar"
    password_confirmation "foobar"
    # login "test"
    sequence(:login) { |n| "tester#{n}" }
  end

  factory :scerevisiae_hsapien_ortholog do
    sequence(:humanEnsemblID) { |n| "ENSG00000136450" }
    humanGeneName "SRSF1"
    yeastOrf "YFL039C" # actin
    percentIdentityWithRespectToQueryGene "20"
    percentIdentityWithRespectToYeastGene "21"
    homologyType 'test'
    source 'test'
    approved '0'
    created_by "test"
    updated_by "test"
    # sequence(:login) { |n| "tester#{n}" }
  end

  factory :experiment do
    date "2014-02-05"
    density 1536
    comparer "pWJ1512"
    query "pWJ1786"
    condition "0uM Cu"
    replicates "4"
    screen_type "SDL"
    library_used "Rothstein HB Deletion Library (MATalpha - 384 strains / plate, for screening)"
    donor_strain_used "W8164-2C"
    comments "blah"
    screen_purpose "Primary Screen"
    number_of_plates 16
    updated_by "test"
    created_by "test"
  end
end