// Karma configuration
// http://karma-runner.github.io/0.12/config/configuration-file.html

module.exports = function(config) {
  'use strict';

  config.set({
    // testing framework to use (jasmine/mocha/qunit/...)
    frameworks: ['mocha', 'browserify'],

    // base path, that will be used to resolve files and exclude
    basePath: '../',

    // list of files / patterns to load in the browser
    files: [
      'spec/**/*.coffee'
    ],

    preprocessors: {
      'spec/**/*.coffee': [ 'browserify' ]
    },

    browserify: {
      debug: true,
      transform: [ 'coffeeify' ],
      extensions: ['.coffee']
    },

    // list of files / patterns to exclude
    exclude: [],

    // web server port
    port: 9876,

    //A list of reporters to use.
    reporters: [ 'dots' ],

    // Start these browsers, currently available:
    // - Chrome
    // - ChromeCanary
    // - Firefox
    // - Opera
    // - Safari (only Mac)
    // - PhantomJS
    // - IE (only Windows)
    browsers: ['Chrome'],

    // enable / disable watching file and executing tests whenever any file changes
    autoWatch: false,
    // Continuous Integration mode
    // if true, it capture browsers, run tests and exit
    singleRun: true,

    colors: true,

    // level of logging
    // possible values: LOG_DISABLE || LOG_ERROR || LOG_WARN || LOG_INFO || LOG_DEBUG
    logLevel: config.LOG_INFO,
  });
};
