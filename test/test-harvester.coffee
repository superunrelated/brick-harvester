
Harvester = require('../src/harvester')

chai = require 'chai'
chai.should()

describe('Harvester', ->
	# beforeEach() ->
	# 	harvester = new Harvester()

	describe('Harvester.unique()', ->
		it('Empty input should return an empty array', ()->
			Harvester.unique([], 'u', ['a, b, c']).should.be.a('array')
		)

		it('should return array with a length of 1 when unique value is 0', ()->
			arr = Harvester.unique([
				{
					u: 0
					a: 'a1'
					b: 'b1'
					c: 'c1'
				},{
					u: 0
					a: 'a2'
					b: 'b2'
					c: 'c2'
				}
			], 'u', ['a'])
			arr.should.be.a('array')
			arr.should.have.length(1)
			arr[0].should.have.property('a')
			arr[0]['a'].should.equal('a1')
			arr[0].should.not.have.property('b')
			arr[0].should.not.have.property('c')
		)

		it('should return array with a length of 1 when unique value is int', ()->
			arr = Harvester.unique([
				{
					u: 1
					a: 'a1'
					b: 'b1'
					c: 'c1'
				},{
					u: 1
					a: 'a2'
					b: 'b2'
					c: 'c2'
				}
			], 'u', ['a'])
			arr.should.be.a('array')
			arr.should.have.length(1)
			arr[0].should.have.property('a')
			arr[0]['a'].should.equal('a1')
			arr[0].should.not.have.property('b')
			arr[0].should.not.have.property('c')
		)

		it('should return array with a length of 2 when unique value is int', ()->
			arr = Harvester.unique([
				{
					u: 1
					a: 'a1'
					b: 'b1'
					c: 'c1'
				},{
					u: 2
					a: 'a2'
					b: 'b2'
					c: 'c2'
				}
			], 'u', ['b'])
			arr.should.be.a('array')
			arr.should.have.length(2)

			arr[0].should.have.property('b')
			arr[0]['b'].should.equal('b1')
			arr[0].should.not.have.property('a')
			arr[0].should.not.have.property('c')

			arr[1].should.have.property('b')
			arr[1]['b'].should.equal('b2')
			arr[1].should.not.have.property('a')
			arr[1].should.not.have.property('c')
		)

		it('should return array with a length of 1 when unique value is string', ()->
			arr = Harvester.unique([
				{
					u: "a"
					a: 'a1'
					b: 'b1'
					c: 'c1'
				},{
					u: "a"
					a: 'a2'
					b: 'b2'
					c: 'c2'
				}
			], 'u', ['a'])
			arr.should.be.a('array')
			arr.should.have.length(1)
			arr[0].should.have.property('a')
			arr[0]['a'].should.equal('a1')
			arr[0].should.not.have.property('b')
			arr[0].should.not.have.property('c')
		)

		it('should return array with a length of 2 when unique value is string', ()->
			arr = Harvester.unique([
				{
					u: "a"
					a: 'a1'
					b: 'b1'
					c: 'c1'
				},{
					u: "b"
					a: 'a2'
					b: 'b2'
					c: 'c2'
				}
			], 'u', ['b'])
			arr.should.be.a('array')
			arr.should.have.length(2)

			arr[0].should.have.property('b')
			arr[0]['b'].should.equal('b1')
			arr[0].should.not.have.property('a')
			arr[0].should.not.have.property('c')

			arr[1].should.have.property('b')
			arr[1]['b'].should.equal('b2')
			arr[1].should.not.have.property('a')
			arr[1].should.not.have.property('c')
		)

		it('should return all properties in keys', ()->
			arr = Harvester.unique([
				{
					u: "a"
					a: 'a1'
					b: 'b1'
					c: 'c1'
				}
			], 'u', ['a', 'b', 'c'])
			arr.should.be.a('array')
			arr.should.have.length(1)

			arr[0].should.have.property('a')
			arr[0].should.have.property('b')
			arr[0].should.have.property('c')

			arr[0]['a'].should.equal('a1')
			arr[0]['b'].should.equal('b1')
			arr[0]['c'].should.equal('c1')
		)




	)
)