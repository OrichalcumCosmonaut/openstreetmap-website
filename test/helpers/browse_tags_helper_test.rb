require "test_helper"

class BrowseTagsHelperTest < ActionView::TestCase
  include ERB::Util
  include ApplicationHelper

  def test_format_key
    html = format_key("highway")
    assert_dom_equal "<a href=\"https://wiki.openstreetmap.org/wiki/Key:highway?uselang=en\" title=\"The wiki description page for the highway tag\">highway</a>", html

    html = format_key("unknown")
    assert_dom_equal "unknown", html
  end

  def test_format_value
    html = format_value("highway", "primary")
    assert_dom_equal "<a href=\"https://wiki.openstreetmap.org/wiki/Tag:highway=primary?uselang=en\" title=\"The wiki description page for the highway=primary tag\">primary</a>", html

    html = format_value("highway", "unknown")
    assert_dom_equal "unknown", html

    html = format_value("unknown", "unknown")
    assert_dom_equal "unknown", html

    html = format_value("unknown", "abc;def")
    assert_dom_equal "abc;def", html

    html = format_value("unknown", "foo;")
    assert_dom_equal "foo;", html

    html = format_value("addr:street", "Rue de l'Amigo")
    assert_dom_equal "Rue de l&#39;Amigo", html

    html = format_value("phone", "+1234567890")
    assert_dom_equal "<a href=\"tel:+1234567890\" title=\"Call +1234567890\">+1234567890</a>", html

    html = format_value("phone", "+1 (234) 567-890 ;  +22334455")
    assert_dom_equal "<a href=\"tel:+1(234)567-890\" title=\"Call +1 (234) 567-890\">+1 (234) 567-890</a>; <a href=\"tel:+22334455\" title=\"Call +22334455\">+22334455</a>", html

    html = format_value("wikipedia", "Test")
    assert_dom_equal "<a title=\"The Test article on Wikipedia\" href=\"https://en.wikipedia.org/wiki/Test?uselang=en\">Test</a>", html

    html = format_value("wikidata", "Q42")
    dom = Rails::Dom::Testing.html_document_fragment.parse html
    assert_select dom, "a[title='The Q42 item on Wikidata'][href$='www.wikidata.org/entity/Q42?uselang=en']", :text => "Q42"
    assert_select dom, "button.wdt-preview>svg>path[fill]", 1

    html = format_value("operator:wikidata", "Q12;Q98")
    dom = Rails::Dom::Testing.html_document_fragment.parse html
    assert_select dom, "a[title='The Q12 item on Wikidata'][href$='www.wikidata.org/entity/Q12?uselang=en']", :text => "Q12"
    assert_select dom, "a[title='The Q98 item on Wikidata'][href$='www.wikidata.org/entity/Q98?uselang=en']", :text => "Q98"
    assert_select dom, "button.wdt-preview>svg>path[fill]", 1

    html = format_value("name:etymology:wikidata", "Q123")
    dom = Rails::Dom::Testing.html_document_fragment.parse html
    assert_select dom, "a[title='The Q123 item on Wikidata'][href$='www.wikidata.org/entity/Q123?uselang=en']", :text => "Q123"
    assert_select dom, "button.wdt-preview>svg>path[fill]", 1

    html = format_value("wikimedia_commons", "File:Test.jpg")
    assert_dom_equal "<a title=\"The File:Test.jpg item on Wikimedia Commons\" href=\"//commons.wikimedia.org/wiki/File:Test.jpg?uselang=en\">File:Test.jpg</a>", html

    html = format_value("mapillary", "123;https://example.com")
    assert_dom_equal "<a rel=\"nofollow\" href=\"https://www.mapillary.com/app/?pKey=123\">123</a>;<a href=\"https://example.com\" rel=\"nofollow\" dir=\"auto\">https://example.com</a>",
                     html

    html = format_value("colour", "#f00")
    dom = Rails::Dom::Testing.html_document_fragment.parse html
    assert_select dom, "svg>rect>@fill", "#f00"
    assert_match(/#f00$/, html)

    html = format_value("email", "foo@example.com")
    assert_dom_equal "<a title=\"Email foo@example.com\" href=\"mailto:foo@example.com\">foo@example.com</a>", html

    html = format_value("source", "https://example.com")
    assert_dom_equal "<a href=\"https://example.com\" rel=\"nofollow\" dir=\"auto\">https://example.com</a>", html

    html = format_value("source", "https://example.com;hello;https://example.net")
    assert_dom_equal "<a href=\"https://example.com\" rel=\"nofollow\" dir=\"auto\">https://example.com</a>;hello;<a href=\"https://example.net\" rel=\"nofollow\" dir=\"auto\">https://example.net</a>", html
  end

  def test_wiki_link
    link = wiki_link("key", "highway")
    assert_equal "https://wiki.openstreetmap.org/wiki/Key:highway?uselang=en", link

    link = wiki_link("tag", "highway=primary")
    assert_equal "https://wiki.openstreetmap.org/wiki/Tag:highway=primary?uselang=en", link

    I18n.with_locale "de" do
      link = wiki_link("key", "highway")
      assert_equal "https://wiki.openstreetmap.org/wiki/DE:Key:highway?uselang=de", link

      link = wiki_link("tag", "highway=primary")
      assert_equal "https://wiki.openstreetmap.org/wiki/DE:Tag:highway=primary?uselang=de", link
    end

    I18n.with_locale "tr" do
      link = wiki_link("key", "highway")
      assert_equal "https://wiki.openstreetmap.org/wiki/Tr:Key:highway?uselang=tr", link

      link = wiki_link("tag", "highway=primary")
      assert_equal "https://wiki.openstreetmap.org/wiki/Tag:highway=primary?uselang=tr", link
    end
  end

  def test_wikidata_links
    ### Non-prefixed wikidata-tag (only one value allowed)

    # Non-wikidata tag
    links = wikidata_links("foo", "Test")
    assert_nil links

    # No URLs allowed
    links = wikidata_links("wikidata", "http://www.wikidata.org/entity/Q1")
    assert_nil links

    # No language-prefixes (as wikidata is multilanguage)
    links = wikidata_links("wikidata", "en:Q1")
    assert_nil links

    # Needs a leading Q
    links = wikidata_links("wikidata", "1")
    assert_nil links

    # No leading zeros allowed
    links = wikidata_links("wikidata", "Q0123")
    assert_nil links

    # A valid value
    links = wikidata_links("wikidata", "Q42")
    assert_equal 1, links.length
    assert_equal "//www.wikidata.org/entity/Q42?uselang=en", links[0][:url]
    assert_equal "Q42", links[0][:title]

    # the language of the wikidata-page should match the current locale
    I18n.with_locale "zh-CN" do
      links = wikidata_links("wikidata", "Q1234")
      assert_equal 1, links.length
      assert_equal "//www.wikidata.org/entity/Q1234?uselang=zh-CN", links[0][:url]
      assert_equal "Q1234", links[0][:title]
    end

    ### Prefixed wikidata-tags

    # Not anything is accepted as prefix (only limited set)
    links = wikidata_links("anything:wikidata", "Q13")
    assert_nil links

    # This for example is an allowed key
    links = wikidata_links("operator:wikidata", "Q24")
    assert_equal "//www.wikidata.org/entity/Q24?uselang=en", links[0][:url]
    assert_equal "Q24", links[0][:title]

    # This verified buried is working
    links = wikidata_links("buried:wikidata", "Q24")
    assert_equal "//www.wikidata.org/entity/Q24?uselang=en", links[0][:url]
    assert_equal "Q24", links[0][:title]

    links = wikidata_links("species:wikidata", "Q26899")
    assert_equal "//www.wikidata.org/entity/Q26899?uselang=en", links[0][:url]
    assert_equal "Q26899", links[0][:title]

    # Another allowed key, this time with multiple values and I18n
    I18n.with_locale "dsb" do
      links = wikidata_links("brand:wikidata", "Q936;Q2013;Q1568346")
      assert_equal 3, links.length
      assert_equal "//www.wikidata.org/entity/Q936?uselang=dsb", links[0][:url]
      assert_equal "Q936", links[0][:title]
      assert_equal "//www.wikidata.org/entity/Q2013?uselang=dsb", links[1][:url]
      assert_equal "Q2013", links[1][:title]
      assert_equal "//www.wikidata.org/entity/Q1568346?uselang=dsb", links[2][:url]
      assert_equal "Q1568346", links[2][:title]
    end

    # and now with whitespaces...
    links = wikidata_links("subject:wikidata", "Q6542248 ;\tQ180\n ;\rQ364\t\n\r ;\nQ4006")
    assert_equal 4, links.length
    assert_equal "//www.wikidata.org/entity/Q6542248?uselang=en", links[0][:url]
    assert_equal "Q6542248 ", links[0][:title]
    assert_equal "//www.wikidata.org/entity/Q180?uselang=en", links[1][:url]
    assert_equal "\tQ180\n ", links[1][:title]
    assert_equal "//www.wikidata.org/entity/Q364?uselang=en", links[2][:url]
    assert_equal "\rQ364\t\n\r ", links[2][:title]
    assert_equal "//www.wikidata.org/entity/Q4006?uselang=en", links[3][:url]
    assert_equal "\nQ4006", links[3][:title]
  end

  def test_wikipedia_link
    link = wikipedia_link("wikipedia", "http://en.wikipedia.org/wiki/Full%20URL")
    assert_nil link

    link = wikipedia_link("wikipedia", "https://en.wikipedia.org/wiki/Full%20URL")
    assert_nil link

    link = wikipedia_link("wikipedia", "Test")
    assert_equal "https://en.wikipedia.org/wiki/Test?uselang=en", link[:url]
    assert_equal "Test", link[:title]

    link = wikipedia_link("wikipedia", "de:Test")
    assert_equal "https://de.wikipedia.org/wiki/Test?uselang=en", link[:url]
    assert_equal "de:Test", link[:title]

    link = wikipedia_link("wikipedia:fr", "Portsea")
    assert_equal "https://fr.wikipedia.org/wiki/Portsea?uselang=en", link[:url]
    assert_equal "Portsea", link[:title]

    link = wikipedia_link("wikipedia:fr", "de:Test")
    assert_equal "https://de.wikipedia.org/wiki/Test?uselang=en", link[:url]
    assert_equal "de:Test", link[:title]

    link = wikipedia_link("wikipedia", "de:Englischer Garten (München)#Japanisches Teehaus")
    assert_equal "https://de.wikipedia.org/wiki/Englischer_Garten_%28M%C3%BCnchen%29?uselang=en#Japanisches_Teehaus", link[:url]
    assert_equal "de:Englischer Garten (München)#Japanisches Teehaus", link[:title]

    link = wikipedia_link("wikipedia", "de:Alte Brücke (Heidelberg)#Brückenaffe")
    assert_equal "https://de.wikipedia.org/wiki/Alte_Br%C3%BCcke_%28Heidelberg%29?uselang=en#Br%C3%BCckenaffe", link[:url]
    assert_equal "de:Alte Brücke (Heidelberg)#Brückenaffe", link[:title]

    link = wikipedia_link("wikipedia", "de:Liste der Baudenkmäler in Eichstätt#Brückenstraße 1, Ehemaliges Bauernhaus")
    assert_equal "https://de.wikipedia.org/wiki/Liste_der_Baudenkm%C3%A4ler_in_Eichst%C3%A4tt?uselang=en#Br%C3%BCckenstra%C3%9Fe_1%2C_Ehemaliges_Bauernhaus", link[:url]
    assert_equal "de:Liste der Baudenkmäler in Eichstätt#Brückenstraße 1, Ehemaliges Bauernhaus", link[:title]

    link = wikipedia_link("wikipedia", "en:Are Years What? (for Marianne Moore)")
    assert_equal "https://en.wikipedia.org/wiki/Are_Years_What%3F_%28for_Marianne_Moore%29?uselang=en", link[:url]
    assert_equal "en:Are Years What? (for Marianne Moore)", link[:title]

    I18n.with_locale "pt-BR" do
      link = wikipedia_link("wikipedia", "zh-classical:Test#Section")
      assert_equal "https://zh-classical.wikipedia.org/wiki/Test?uselang=pt-BR#Section", link[:url]
      assert_equal "zh-classical:Test#Section", link[:title]
    end

    link = wikipedia_link("subject:wikipedia", "en:Catherine McAuley")
    assert_equal "https://en.wikipedia.org/wiki/Catherine_McAuley?uselang=en", link[:url]
    assert_equal "en:Catherine McAuley", link[:title]

    link = wikipedia_link("foo", "Test")
    assert_nil link
  end

  def test_wikimedia_commons_link
    link = wikimedia_commons_link("wikimedia_commons", "http://commons.wikimedia.org/wiki/File:Full%20URL.jpg")
    assert_nil link

    link = wikimedia_commons_link("wikimedia_commons", "https://commons.wikimedia.org/wiki/File:Full%20URL.jpg")
    assert_nil link

    link = wikimedia_commons_link("wikimedia_commons", "Test.jpg")
    assert_nil link

    link = wikimedia_commons_link("wikimedia_commons", "File:Test.jpg")
    assert_equal "//commons.wikimedia.org/wiki/File:Test.jpg?uselang=en", link[:url]
    assert_equal "File:Test.jpg", link[:title]

    link = wikimedia_commons_link("wikimedia_commons", "Category:Test_Category")
    assert_equal "//commons.wikimedia.org/wiki/Category:Test_Category?uselang=en", link[:url]
    assert_equal "Category:Test_Category", link[:title]

    link = wikimedia_commons_link("wikimedia_commons", "Category:What If? (Bonn)")
    assert_equal "//commons.wikimedia.org/wiki/Category:What%20If%3F%20%28Bonn%29?uselang=en", link[:url]
    assert_equal "Category:What If? (Bonn)", link[:title]

    link = wikimedia_commons_link("wikimedia_commons", "File:Corsica-vizzavona-abri-southwell.jpg#mediaviewer/File:Corsica-vizzavona-abri-southwell.jpg")
    assert_equal "//commons.wikimedia.org/wiki/File:Corsica-vizzavona-abri-southwell.jpg?uselang=en", link[:url]
    assert_equal "File:Corsica-vizzavona-abri-southwell.jpg#mediaviewer/File:Corsica-vizzavona-abri-southwell.jpg", link[:title]

    I18n.with_locale "pt-BR" do
      link = wikimedia_commons_link("wikimedia_commons", "File:Test.jpg")
      assert_equal "//commons.wikimedia.org/wiki/File:Test.jpg?uselang=pt-BR", link[:url]
      assert_equal "File:Test.jpg", link[:title]
    end

    link = wikimedia_commons_link("foo", "Test")
    assert_nil link
  end

  def test_email_link
    email = email_link("foo", "Test")
    assert_nil email

    email = email_link("email", "123")
    assert_nil email

    email = email_link("email", "Abc.example.com")
    assert_nil email

    email = email_link("email", "a@b@c.com")
    assert_nil email

    email = email_link("email", "just\"not\"right@example.com")
    assert_nil email

    email = email_link("email", "123 abcdefg@space.com")
    assert_nil email

    email = email_link("email", "test@ abc")
    assert_nil email

    email = email_link("email", "using;semicolon@test.com")
    assert_nil email

    email = email_link("email", "x@example.com")
    assert_equal "x@example.com", email

    email = email_link("email", "other.email-with-hyphen@example.com")
    assert_equal "other.email-with-hyphen@example.com", email

    email = email_link("email", "user.name+tag+sorting@example.com")
    assert_equal "user.name+tag+sorting@example.com", email

    email = email_link("email", "dash-in@both-parts.com")
    assert_equal "dash-in@both-parts.com", email

    email = email_link("email", "example@s.example")
    assert_equal "example@s.example", email

    # Strips whitespace at ends
    email = email_link("email", " test@email.com ")
    assert_equal "test@email.com", email

    email = email_link("contact:email", "example@example.com")
    assert_equal "example@example.com", email

    email = email_link("maxweight:conditional", "none@agricultural")
    assert_nil email
  end

  def test_telephone_links
    links = telephone_links("foo", "Test")
    assert_nil links

    links = telephone_links("phone", "+123")
    assert_nil links

    links = telephone_links("phone", "123")
    assert_nil links

    links = telephone_links("phone", "123 abcdefg")
    assert_nil links

    links = telephone_links("phone", "+1234567890 abc")
    assert_nil links

    # If multiple numbers are listed, all must be valid
    links = telephone_links("phone", "+1234567890; +223")
    assert_nil links

    links = telephone_links("phone", "1234567890")
    assert_nil links

    links = telephone_links("phone", "+1234567890")
    assert_equal 1, links.length
    assert_equal "+1234567890", links[0][:phone_number]
    assert_equal "tel:+1234567890", links[0][:url]

    links = telephone_links("phone", "+1234-567-890")
    assert_equal 1, links.length
    assert_equal "+1234-567-890", links[0][:phone_number]
    assert_equal "tel:+1234-567-890", links[0][:url]

    links = telephone_links("phone", "+1234/567/890")
    assert_equal 1, links.length
    assert_equal "+1234/567/890", links[0][:phone_number]
    assert_equal "tel:+1234/567/890", links[0][:url]

    links = telephone_links("phone", "+1234.567.890")
    assert_equal 1, links.length
    assert_equal "+1234.567.890", links[0][:phone_number]
    assert_equal "tel:+1234.567.890", links[0][:url]

    links = telephone_links("phone", "   +1234 567-890	")
    assert_equal 1, links.length
    assert_equal "+1234 567-890", links[0][:phone_number]
    assert_equal "tel:+1234567-890", links[0][:url]

    links = telephone_links("phone", "+1 234-567-890")
    assert_equal 1, links.length
    assert_equal "+1 234-567-890", links[0][:phone_number]
    assert_equal "tel:+1234-567-890", links[0][:url]

    links = telephone_links("phone", "+1 (234) 567-890")
    assert_equal 1, links.length
    assert_equal "+1 (234) 567-890", links[0][:phone_number]
    assert_equal "tel:+1(234)567-890", links[0][:url]

    # Multiple valid phone numbers separated by ;
    links = telephone_links("phone", "+1234567890; +22334455667788")
    assert_equal 2, links.length
    assert_equal "+1234567890", links[0][:phone_number]
    assert_equal "tel:+1234567890", links[0][:url]
    assert_equal "+22334455667788", links[1][:phone_number]
    assert_equal "tel:+22334455667788", links[1][:url]

    links = telephone_links("phone", "+1 (234) 567-890 ;  +22(33)4455.66.7788 ")
    assert_equal 2, links.length
    assert_equal "+1 (234) 567-890", links[0][:phone_number]
    assert_equal "tel:+1(234)567-890", links[0][:url]
    assert_equal "+22(33)4455.66.7788", links[1][:phone_number]
    assert_equal "tel:+22(33)4455.66.7788", links[1][:url]
  end

  def test_colour_preview
    # basic positive tests
    colour = colour_preview("colour", "red")
    assert_equal "red", colour

    colour = colour_preview("colour", "Red")
    assert_equal "Red", colour

    colour = colour_preview("colour", "darkRed")
    assert_equal "darkRed", colour

    colour = colour_preview("colour", "#f00")
    assert_equal "#f00", colour

    colour = colour_preview("colour", "#fF0000")
    assert_equal "#fF0000", colour

    # other tag variants:
    colour = colour_preview("building:colour", "#f00")
    assert_equal "#f00", colour

    colour = colour_preview("ref:colour", "#f00")
    assert_equal "#f00", colour

    colour = colour_preview("int_ref:colour", "green")
    assert_equal "green", colour

    colour = colour_preview("roof:colour", "#f00")
    assert_equal "#f00", colour

    colour = colour_preview("seamark:beacon_lateral:colour", "#f00")
    assert_equal "#f00", colour

    # negative tests:
    colour = colour_preview("colour", "")
    assert_nil colour

    colour = colour_preview("colour", "   ")
    assert_nil colour

    colour = colour_preview("colour", nil)
    assert_nil colour

    # ignore US spelling variant
    colour = colour_preview("color", "red")
    assert_nil colour

    # irrelevant tag names
    colour = colour_preview("building", "red")
    assert_nil colour

    colour = colour_preview("ref:colour_no", "red")
    assert_nil colour

    colour = colour_preview("ref:colour-bg", "red")
    assert_nil colour

    colour = colour_preview("int_ref", "red")
    assert_nil colour

    # invalid hex codes
    colour = colour_preview("colour", "#")
    assert_nil colour

    colour = colour_preview("colour", "#ff")
    assert_nil colour

    colour = colour_preview("colour", "#ffff")
    assert_nil colour

    colour = colour_preview("colour", "#fffffff")
    assert_nil colour

    colour = colour_preview("colour", "#ggg")
    assert_nil colour

    colour = colour_preview("colour", "#ff 00 00")
    assert_nil colour

    # invalid w3c color names:
    colour = colour_preview("colour", "r")
    assert_nil colour

    colour = colour_preview("colour", "ffffff")
    assert_nil colour

    colour = colour_preview("colour", "f00")
    assert_nil colour

    colour = colour_preview("colour", "xxxred")
    assert_nil colour

    colour = colour_preview("colour", "dark red")
    assert_nil colour

    colour = colour_preview("colour", "dark_red")
    assert_nil colour

    colour = colour_preview("colour", "ADarkDummyLongColourNameWithAPurpleUndertone")
    assert_nil colour
  end
end
