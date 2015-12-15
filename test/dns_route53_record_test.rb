require 'test_helper'

require 'smart_proxy_dns_route53/dns_route53_plugin'
require 'smart_proxy_dns_route53/dns_route53_main'

class DnsRoute53RecordTest < Test::Unit::TestCase
  # Test that correct initialization works
  def test_provider_initialization
    Proxy::Dns::Route53::Plugin.load_test_settings(:aws_access_key => 'foo', :aws_secret_key => 'bar')
    provider = klass.new
    assert_equal 'foo', provider.aws_access_key
    assert_equal 'bar', provider.aws_secret_key
  end

  # Test A record creation
  def test_create_a
    record = klass.new
    record.expects(:dns_find).returns(false)

    zone = mock()
    record.expects(:get_zone).with('test.example.com').returns(zone)

    dnsrecord = mock(:create => mock(:error? => false))
    Route53::DNSRecord.expects(:new).with('test.example.com', 'A', 86400, ['10.1.1.1'], zone).returns(dnsrecord)

    assert record.create_a_record(fqdn, ip)
  end

  # Test A record creation fails if the record exists
  def test_create_a_conflict
    record = klass.new
    record.expects(:dns_find).returns('10.2.2.2')
    assert_raise(Proxy::Dns::Collision) { record.create_a_record(fqdn, ip) }
  end

  # Test PTR record creation
  def test_create_ptr
    record = klass.new
    record.expects(:dns_find).returns(false)

    zone = mock()
    record.expects(:get_zone).with('10.1.1.1').returns(zone)

    dnsrecord = mock(:create => mock(:error? => false))
    Route53::DNSRecord.expects(:new).with('10.1.1.1', 'PTR', 86400, ['test.example.com'], zone).returns(dnsrecord)

    assert record.create_ptr_record(fqdn, ip)
  end

  # Test PTR record creation fails if the record exists
  def test_create_ptr_conflict
    record = klass.new
    record.expects(:dns_find).returns('else.example.com')
    assert_raise(Proxy::Dns::Collision) { record.create_ptr_record(fqdn, ip) }
  end

  # Test A record removal
  def test_remove_a
    zone = mock(:get_records => [mock(:name => 'test.example.com.', :delete => mock(:error? => false))])
    record = klass.new
    record.expects(:get_zone).with('test.example.com').returns(zone)
    assert record.remove_a_record(fqdn)
  end

  # Test A record removal fails if the record doesn't exist
  def test_remove_a_not_found
    record = klass.new
    record.expects(:get_zone).with('test.example.com').returns(mock(:get_records => []))
    assert_raise(Proxy::Dns::NotFound) { assert record.remove_a_record(fqdn) }
  end

  # Test PTR record removal
  def test_remove_ptr
    # FIXME: record name seems incorrect for rDNS
    zone = mock(:get_records => [mock(:name => '10.1.1.1.', :delete => mock(:error? => false))])
    record = klass.new
    record.expects(:get_zone).with('10.1.1.1').returns(zone)
    assert record.remove_ptr_record(ip)
  end

  # Test PTR record removal fails if the record doesn't exist
  def test_remove_ptr_not_found
    record = klass.new
    record.expects(:get_zone).with('10.1.1.1').returns(mock(:get_records => []))
    assert_raise(Proxy::Dns::NotFound) { assert record.remove_ptr_record(ip) }
  end

  def test_get_zone_forward
    record = klass.new
    conn = mock()
    conn.expects(:get_zones).with('example.com.').returns([:zone])
    record.expects(:conn).returns(conn)
    assert_equal :zone, record.send(:get_zone, 'test.example.com')
  end

  def test_get_zone_reverse
    record = klass.new
    conn = mock()
    conn.expects(:get_zones).with('1.1.1.').returns([:zone])  # FIXME, incorrect rDNS zone
    record.expects(:conn).returns(conn)
    assert_equal :zone, record.send(:get_zone, '10.1.1.1')
  end

  def test_dns_find_forward
    record = klass.new
    resolver = mock()
    resolver.expects(:getaddress).with('test.example.com').returns('10.1.1.1')
    record.expects(:resolver).returns(resolver)
    assert_equal '10.1.1.1', record.send(:dns_find, 'test.example.com')
  end

  def test_dns_find_forward_not_found
    record = klass.new
    resolver = mock()
    resolver.expects(:getaddress).with('test.example.com').raises(Resolv::ResolvError)
    record.expects(:resolver).returns(resolver)
    refute record.send(:dns_find, 'test.example.com')
  end

  def test_dns_find_reverse
    record = klass.new
    resolver = mock()
    resolver.expects(:getname).with('3.2.1.10').returns('test.example.com')
    record.expects(:resolver).returns(resolver)
    assert_equal 'test.example.com', record.send(:dns_find, '10.1.2.3')
  end

  def test_dns_find_reverse_not_found
    record = klass.new
    resolver = mock()
    resolver.expects(:getname).with('3.2.1.10').raises(Resolv::ResolvError)
    record.expects(:resolver).returns(resolver)
    refute record.send(:dns_find, '10.1.2.3')
  end

  private

  def klass
    Proxy::Dns::Route53::Record
  end

  def fqdn
    'test.example.com'
  end

  def ip
    '10.1.1.1'
  end
end
