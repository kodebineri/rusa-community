import { MongoDatabase } from '../types/mongo';

export function generateSampleDatabases(): Record<string, MongoDatabase> {
  return {
    sample_mflix: {
      name: 'sample_mflix',
      collections: {
        movies: {
          name: 'movies',
          indexes: [
            { name: '_id_', keys: { _id: 1 }, sizeKb: 32 },
            { name: 'title_text', keys: { title: 'text' }, sizeKb: 64 },
            { name: 'year_-1_imdb.rating_-1', keys: { year: -1, 'imdb.rating': -1 }, sizeKb: 48 },
            { name: 'genres_1', keys: { genres: 1 }, sizeKb: 36 }
          ],
          documents: [
            {
              _id: '573a1390f29313caabcd4135',
              title: 'The Great Train Robbery',
              plot: 'A group of bandits stage a brazen train hold-up, only to find a determined posse hot on their heels.',
              genres: ['Short', 'Western', 'Action'],
              runtime: 11,
              cast: ['A.C. Abadie', 'Gilbert M. Anderson', 'George Barnes'],
              num_mflix_comments: 1,
              poster: 'https://images.unsplash.com/photo-1536440136628-849c177e76a1?w=400',
              fullplot: 'Among the earliest existing films in American cinema, notable for innovations like composite editing and cross-cutting.',
              languages: ['English'],
              released: '1903-12-01T00:00:00.000Z',
              directors: ['Edwin S. Porter'],
              rated: 'TV-G',
              awards: { wins: 1, nominations: 0, text: '1 win.' },
              lastupdated: '2015-08-13T00:27:59.000Z',
              year: 1903,
              imdb: { rating: 7.4, votes: 9847, id: 439 },
              type: 'movie'
            },
            {
              _id: '573a1390f29313caabcd42e8',
              title: 'The Cabinet of Dr. Caligari',
              plot: 'Hypnotist Dr. Caligari uses a somnambulist, Cesare, to commit murders in a sleepy German town.',
              genres: ['Horror', 'Mystery', 'Thriller'],
              runtime: 67,
              cast: ['Werner Krauss', 'Conrad Veidt', 'Friedrich Feher', 'Lil Dagover'],
              num_mflix_comments: 4,
              poster: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=400',
              languages: ['German'],
              released: '1920-02-26T00:00:00.000Z',
              directors: ['Robert Wiene'],
              rated: 'UNRATED',
              awards: { wins: 2, nominations: 1, text: '2 wins & 1 nomination.' },
              lastupdated: '2015-08-11T00:02:19.000Z',
              year: 1920,
              imdb: { rating: 8.1, votes: 57482, id: 10323 },
              type: 'movie'
            },
            {
              _id: '573a1390f29313caabcd446f',
              title: 'Metropolis',
              plot: 'In a futuristic city sharply divided between the working class and the city planners, the son of the city mastermind falls in love with a working class prophet.',
              genres: ['Drama', 'Sci-Fi'],
              runtime: 153,
              cast: ['Alfred Abel', 'Gustav Frohlich', 'Brigitte Helm', 'Rudolf Klein-Rogge'],
              num_mflix_comments: 8,
              poster: 'https://images.unsplash.com/photo-1478720568477-152d9b164e26?w=400',
              languages: ['German'],
              released: '1927-03-13T00:00:00.000Z',
              directors: ['Fritz Lang'],
              rated: 'NOT RATED',
              awards: { wins: 3, nominations: 4, text: '3 wins & 4 nominations.' },
              lastupdated: '2015-08-22T00:44:43.000Z',
              year: 1927,
              imdb: { rating: 8.3, votes: 143200, id: 17136 },
              type: 'movie'
            },
            {
              _id: '573a1390f29313caabcd512a',
              title: 'Casablanca',
              plot: 'A cynical American expatriate struggles to decide whether or not he should help his former lover and her fugitive husband escape French Morocco.',
              genres: ['Drama', 'Romance', 'War'],
              runtime: 102,
              cast: ['Humphrey Bogart', 'Ingrid Bergman', 'Paul Henreid', 'Claude Rains'],
              num_mflix_comments: 12,
              languages: ['English', 'French', 'German', 'Italian'],
              released: '1943-01-23T00:00:00.000Z',
              directors: ['Michael Curtiz'],
              rated: 'PG',
              awards: { wins: 3, nominations: 5, text: 'Won 3 Oscars. Another 5 wins & 5 nominations.' },
              lastupdated: '2015-09-02T00:11:23.000Z',
              year: 1942,
              imdb: { rating: 8.5, votes: 512930, id: 34583 },
              type: 'movie'
            },
            {
              _id: '573a1390f29313caabcd588c',
              title: 'Seven Samurai',
              plot: 'A poor village under attack by bandits recruits seven unemployed samurai to help them defend themselves.',
              genres: ['Action', 'Drama', 'Adventure'],
              runtime: 207,
              cast: ['Toshirô Mifune', 'Takashi Shimura', 'Keiko Tsushima'],
              num_mflix_comments: 6,
              languages: ['Japanese'],
              released: '1954-04-26T00:00:00.000Z',
              directors: ['Akira Kurosawa'],
              rated: 'UNRATED',
              awards: { wins: 5, nominations: 3, text: 'Nominated for 2 Oscars. Another 5 wins & 3 nominations.' },
              lastupdated: '2015-08-30T00:32:01.000Z',
              year: 1954,
              imdb: { rating: 8.6, votes: 312000, id: 47478 },
              type: 'movie'
            },
            {
              _id: '573a1391f29313caabcd68f1',
              title: 'The Godfather',
              plot: 'The aging patriarch of an organized crime dynasty transfers control of his clandestine empire to his reluctant son.',
              genres: ['Crime', 'Drama'],
              runtime: 175,
              cast: ['Marlon Brando', 'Al Pacino', 'James Caan', 'Robert Duvall'],
              num_mflix_comments: 18,
              languages: ['English', 'Italian', 'Latin'],
              released: '1972-03-24T00:00:00.000Z',
              directors: ['Francis Ford Coppola'],
              rated: 'R',
              awards: { wins: 26, nominations: 30, text: 'Won 3 Oscars. Another 26 wins & 30 nominations.' },
              lastupdated: '2015-09-15T00:45:11.000Z',
              year: 1972,
              imdb: { rating: 9.2, votes: 1620000, id: 68646 },
              type: 'movie'
            },
            {
              _id: '573a1391f29313caabcd778a',
              title: 'Blade Runner',
              plot: 'A blade runner must pursue and terminate four replicants who stole a ship in space and have returned to Earth to find their creator.',
              genres: ['Action', 'Sci-Fi', 'Thriller'],
              runtime: 117,
              cast: ['Harrison Ford', 'Rutger Hauer', 'Sean Young', 'Edward James Olmos'],
              num_mflix_comments: 9,
              languages: ['English', 'German', 'Cantonese', 'Japanese'],
              released: '1982-06-25T00:00:00.000Z',
              directors: ['Ridley Scott'],
              rated: 'R',
              awards: { wins: 12, nominations: 16, text: 'Nominated for 2 Oscars. Another 12 wins & 16 nominations.' },
              lastupdated: '2015-09-08T00:22:34.000Z',
              year: 1982,
              imdb: { rating: 8.1, votes: 702000, id: 83658 },
              type: 'movie'
            },
            {
              _id: '573a1392f29313caabcd882c',
              title: 'Pulp Fiction',
              plot: 'The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine in four tales of violence and redemption.',
              genres: ['Crime', 'Drama'],
              runtime: 154,
              cast: ['John Travolta', 'Uma Thurman', 'Samuel L. Jackson', 'Bruce Willis'],
              num_mflix_comments: 14,
              languages: ['English', 'Spanish', 'French'],
              released: '1994-10-14T00:00:00.000Z',
              directors: ['Quentin Tarantino'],
              rated: 'R',
              awards: { wins: 63, nominations: 69, text: 'Won 1 Oscar. Another 63 wins & 69 nominations.' },
              lastupdated: '2015-09-12T00:30:19.000Z',
              year: 1994,
              imdb: { rating: 8.9, votes: 1820000, id: 110912 },
              type: 'movie'
            },
            {
              _id: '573a1393f29313caabcd991e',
              title: 'The Matrix',
              plot: 'When a beautiful stranger leads computer hacker Neo to a forbidding underworld, he discovers the shocking truth--the life he knows is the elaborate deception of an evil cyber-intelligence.',
              genres: ['Action', 'Sci-Fi'],
              runtime: 136,
              cast: ['Keanu Reeves', 'Laurence Fishburne', 'Carrie-Anne Moss', 'Hugo Weaving'],
              num_mflix_comments: 21,
              languages: ['English'],
              released: '1999-03-31T00:00:00.000Z',
              directors: ['Lana Wachowski', 'Lilly Wachowski'],
              rated: 'R',
              awards: { wins: 37, nominations: 50, text: 'Won 4 Oscars. Another 37 wins & 50 nominations.' },
              lastupdated: '2015-09-01T00:15:00.000Z',
              year: 1999,
              imdb: { rating: 8.7, votes: 1680000, id: 133093 },
              type: 'movie'
            },
            {
              _id: '573a1394f29313caabcda102',
              title: 'Spirited Away',
              plot: 'During her family\'s move to the suburbs, a sullen 10-year-old girl wanders into a world ruled by gods, witches, and spirits, and where humans are changed into beasts.',
              genres: ['Animation', 'Adventure', 'Family', 'Fantasy'],
              runtime: 125,
              cast: ['Rumi Hiiragi', 'Miyu Irino', 'Mari Natsuki', 'Takashi Naito'],
              num_mflix_comments: 7,
              languages: ['Japanese'],
              released: '2001-07-20T00:00:00.000Z',
              directors: ['Hayao Miyazaki'],
              rated: 'PG',
              awards: { wins: 56, nominations: 28, text: 'Won 1 Oscar. Another 56 wins & 28 nominations.' },
              lastupdated: '2015-09-18T00:41:10.000Z',
              year: 2001,
              imdb: { rating: 8.6, votes: 650000, id: 245429 },
              type: 'movie'
            },
            {
              _id: '573a1395f29313caabcda991',
              title: 'Interstellar',
              plot: 'A team of explorers travel through a wormhole in space in an attempt to ensure humanity\'s survival.',
              genres: ['Adventure', 'Drama', 'Sci-Fi'],
              runtime: 169,
              cast: ['Matthew McConaughey', 'Anne Hathaway', 'Jessica Chastain', 'Michael Caine'],
              num_mflix_comments: 29,
              languages: ['English'],
              released: '2014-11-07T00:00:00.000Z',
              directors: ['Christopher Nolan'],
              rated: 'PG-13',
              awards: { wins: 44, nominations: 144, text: 'Won 1 Oscar. Another 44 wins & 144 nominations.' },
              lastupdated: '2015-09-11T00:04:15.000Z',
              year: 2014,
              imdb: { rating: 8.7, votes: 1910000, id: 816692 },
              type: 'movie'
            },
            {
              _id: '573a1396f29313caabcdb22f',
              title: 'Parasite',
              plot: 'Greed and class discrimination threaten the newly formed symbiotic relationship between the wealthy Park family and the destitute Kim clan.',
              genres: ['Drama', 'Thriller'],
              runtime: 132,
              cast: ['Song Kang-ho', 'Lee Sun-kyun', 'Cho Yeo-jeong', 'Choi Woo-shik'],
              num_mflix_comments: 15,
              languages: ['Korean', 'English'],
              released: '2019-11-08T00:00:00.000Z',
              directors: ['Bong Joon Ho'],
              rated: 'R',
              awards: { wins: 308, nominations: 268, text: 'Won 4 Oscars. Another 308 wins & 268 nominations.' },
              lastupdated: '2020-03-01T00:00:00.000Z',
              year: 2019,
              imdb: { rating: 8.5, votes: 840000, id: 6751668 },
              type: 'movie'
            }
          ]
        },
        comments: {
          name: 'comments',
          indexes: [
            { name: '_id_', keys: { _id: 1 }, sizeKb: 16 },
            { name: 'movie_id_1', keys: { movie_id: 1 }, sizeKb: 24 }
          ],
          documents: [
            {
              _id: '5a9427648b0beebeb69579cc',
              name: 'John Snow',
              email: 'john_snow@gameofthrones.com',
              movie_id: '573a1391f29313caabcd68f1',
              text: 'An absolute masterpiece of cinema. Marlon Brando delivers an iconic performance.',
              date: '2016-04-12T03:45:11.000Z'
            },
            {
              _id: '5a9427648b0beebeb69579cd',
              name: 'Arya Stark',
              email: 'arya_stark@gameofthrones.com',
              movie_id: '573a1393f29313caabcd991e',
              text: 'The bullet time scene completely revolutionized special effects forever.',
              date: '2017-08-19T14:20:00.000Z'
            },
            {
              _id: '5a9427648b0beebeb69579ce',
              name: 'Dana Scully',
              email: 'scully@fbi.gov',
              movie_id: '573a1395f29313caabcda991',
              text: 'The gravitational mechanics and relativistic time dilation were stunningly researched.',
              date: '2018-01-05T09:12:44.000Z'
            }
          ]
        },
        top_rated_movies_view: {
          name: 'top_rated_movies_view',
          isView: true,
          viewOn: 'movies',
          pipeline: [
            { $match: { 'imdb.rating': { $gte: 8.5 } } },
            { $sort: { 'imdb.rating': -1 } },
            { $project: { title: 1, year: 1, 'imdb.rating': 1, directors: 1, genres: 1 } }
          ],
          indexes: [{ name: '_id_', keys: { _id: 1 }, sizeKb: 0 }],
          documents: []
        }
      }
    },
    sample_analytics: {
      name: 'sample_analytics',
      collections: {
        customers: {
          name: 'customers',
          indexes: [
            { name: '_id_', keys: { _id: 1 }, sizeKb: 28 },
            { name: 'username_1', keys: { username: 1 }, unique: true, sizeKb: 32 },
            { name: 'tier_1', keys: { tier: 1 }, sizeKb: 20 }
          ],
          documents: [
            {
              _id: '5ca4bbcea2dd94ee5813238c',
              username: 'fmiller',
              name: 'Elizabeth Ray',
              address: '9286 Quentin Road, Brooklyn, NY 11223',
              birthdate: '1977-03-02T02:20:31.000Z',
              email: 'eliz_ray@yahoo.com',
              active: true,
              tier: 'Platinum',
              accounts: [371138, 324251],
              creditScore: 785
            },
            {
              _id: '5ca4bbcea2dd94ee5813238d',
              username: 'michaelt',
              name: 'Michael Thompson',
              address: '744 Evergreen Terrace, Springfield, OR 97477',
              birthdate: '1984-11-19T11:45:10.000Z',
              email: 'm.thompson@gmail.com',
              active: true,
              tier: 'Gold',
              accounts: [829104],
              creditScore: 712
            },
            {
              _id: '5ca4bbcea2dd94ee5813238e',
              username: 'sarah_k',
              name: 'Sarah Jenkins',
              address: '1042 Market St, San Francisco, CA 94103',
              birthdate: '1992-06-14T18:02:50.000Z',
              email: 'sarah.j@techcorp.io',
              active: false,
              tier: 'Silver',
              accounts: [492019, 582012],
              creditScore: 680
            },
            {
              _id: '5ca4bbcea2dd94ee5813238f',
              username: 'alex_d',
              name: 'Alexander Davis',
              address: '500 W Madison St, Chicago, IL 60661',
              birthdate: '1989-08-30T10:15:20.000Z',
              email: 'alex.davis@chicago-law.com',
              active: true,
              tier: 'Platinum',
              accounts: [102938, 928374, 564738],
              creditScore: 820
            }
          ]
        },
        transactions: {
          name: 'transactions',
          indexes: [
            { name: '_id_', keys: { _id: 1 }, sizeKb: 24 },
            { name: 'account_id_1', keys: { account_id: 1 }, sizeKb: 32 }
          ],
          documents: [
            {
              _id: '5ca4bbcea2dd94ee581329a1',
              account_id: 371138,
              transaction_count: 3,
              bucket_start_date: '1995-01-15T00:00:00.000Z',
              transactions: [
                { date: '2023-01-04T12:00:00.000Z', amount: 450.75, transaction_code: 'buy', symbol: 'aapl', price: 142.5 },
                { date: '2023-01-12T15:30:00.000Z', amount: 1200.0, transaction_code: 'buy', symbol: 'msft', price: 238.1 },
                { date: '2023-02-01T09:45:00.000Z', amount: 800.5, transaction_code: 'sell', symbol: 'goog', price: 92.4 }
              ]
            },
            {
              _id: '5ca4bbcea2dd94ee581329a2',
              account_id: 829104,
              transaction_count: 2,
              bucket_start_date: '2010-04-20T00:00:00.000Z',
              transactions: [
                { date: '2023-03-10T11:20:00.000Z', amount: 2500.0, transaction_code: 'buy', symbol: 'nvda', price: 220.0 },
                { date: '2023-04-05T14:15:00.000Z', amount: 1500.0, transaction_code: 'sell', symbol: 'amzn', price: 102.3 }
              ]
            }
          ]
        },
        active_customers_view: {
          name: 'active_customers_view',
          isView: true,
          viewOn: 'customers',
          pipeline: [
            { $match: { active: true } },
            { $project: { username: 1, name: 1, email: 1, tier: 1, creditScore: 1 } }
          ],
          indexes: [{ name: '_id_', keys: { _id: 1 }, sizeKb: 0 }],
          documents: []
        }
      }
    },
    sample_supplies: {
      name: 'sample_supplies',
      collections: {
        sales: {
          name: 'sales',
          indexes: [
            { name: '_id_', keys: { _id: 1 }, sizeKb: 36 },
            { name: 'storeLocation_1', keys: { storeLocation: 1 }, sizeKb: 28 },
            { name: 'saleDate_-1', keys: { saleDate: -1 }, sizeKb: 40 }
          ],
          documents: [
            {
              _id: '5bd761dcae323f45610ff632',
              saleDate: '2023-03-23T07:53:59.000Z',
              items: [
                { name: 'printer paper', tags: ['office', 'stationary'], price: 40.01, quantity: 2 },
                { name: 'notepad', tags: ['office', 'writing', 'school'], price: 35.29, quantity: 4 },
                { name: 'pens', tags: ['writing', 'office'], price: 56.12, quantity: 5 }
              ],
              storeLocation: 'Denver',
              customer: { gender: 'M', age: 42, email: 'caurow@sor.je', satisfaction: 4 },
              couponUsed: true,
              purchaseMethod: 'Online'
            },
            {
              _id: '5bd761dcae323f45610ff633',
              saleDate: '2023-08-25T10:02:16.000Z',
              items: [
                { name: 'envelopes', tags: ['stationary', 'office'], price: 19.95, quantity: 8 },
                { name: 'binder', tags: ['school', 'general', 'organization'], price: 14.15, quantity: 3 }
              ],
              storeLocation: 'Seattle',
              customer: { gender: 'F', age: 35, email: 'monica.g@haven.com', satisfaction: 5 },
              couponUsed: false,
              purchaseMethod: 'In store'
            },
            {
              _id: '5bd761dcae323f45610ff634',
              saleDate: '2023-09-02T16:42:08.000Z',
              items: [
                { name: 'laptop stand', tags: ['electronics', 'ergonomics'], price: 89.99, quantity: 1 },
                { name: 'wireless mouse', tags: ['electronics', 'accessories'], price: 45.50, quantity: 2 }
              ],
              storeLocation: 'Austin',
              customer: { gender: 'M', age: 29, email: 'k.chen@startup.co', satisfaction: 5 },
              couponUsed: true,
              purchaseMethod: 'Online'
            },
            {
              _id: '5bd761dcae323f45610ff635',
              saleDate: '2023-11-14T13:21:44.000Z',
              items: [
                { name: 'whiteboard markers', tags: ['office', 'teaching'], price: 12.99, quantity: 6 },
                { name: 'sticky notes pack', tags: ['office', 'stationary'], price: 8.50, quantity: 10 }
              ],
              storeLocation: 'New York',
              customer: { gender: 'F', age: 51, email: 'patricia.w@edu.org', satisfaction: 3 },
              couponUsed: false,
              purchaseMethod: 'Phone'
            }
          ]
        }
      }
    }
  };
}
